import 'dart:convert';
import 'dart:typed_data';

import 'claude_client.dart';
import 'gemini_client.dart';

/// Herramienta que el agente puede usar. `schema` es JSON Schema estricto
/// (estilo Claude); cada backend lo adapta a su proveedor.
class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    required this.schema,
  });

  final String name;
  final String description;
  final Map<String, Object?> schema;
}

class ToolCall {
  const ToolCall({required this.id, required this.name, required this.args});
  final String id;
  final String name;
  final Map<String, Object?> args;
}

class ToolResult {
  const ToolResult(this.call, this.output, {this.isError = false});
  final ToolCall call;

  /// JSON de salida (o texto de error).
  final String output;
  final bool isError;
}

class AgentStep {
  const AgentStep({required this.text, required this.calls});
  final String text;
  final List<ToolCall> calls;
}

/// Una conversación con un proveedor. El historial vive aquí, en el formato
/// del proveedor, y solo se agrega al final: cada respuesta se devuelve tal
/// cual (los dos proveedores lo exigen para su razonamiento interno).
abstract interface class AgentBackend {
  /// Proveedor, para mostrarlo en la app.
  String get label;
  void addUserText(String text);
  Future<AgentStep> step({
    required String system,
    required List<ToolSpec> tools,
  });
  void addToolResults(List<ToolResult> results);
}

/// Pide al modelo el JSON del escáner de platos.
abstract interface class ScanBackend {
  Future<String> scanJson({
    required String system,
    required Uint8List image,
    required String mediaType,
  });
}

/// Un proveedor que sirve para conversar y para escanear platos.
abstract interface class AiBackend implements AgentBackend, ScanBackend {}

// ------------------------------------------------------------------ Claude

class ClaudeBackend implements AiBackend {
  ClaudeBackend(this._client);
  final ClaudeClient _client;
  final List<Map<String, Object?>> _messages = [];

  @override
  String get label => 'Claude';

  @override
  void addUserText(String text) =>
      _messages.add({'role': 'user', 'content': text});

  @override
  Future<AgentStep> step({
    required String system,
    required List<ToolSpec> tools,
  }) async {
    final res = await _client.create(
      system: system,
      messages: _messages,
      tools: [
        for (final t in tools)
          {
            'name': t.name,
            'description': t.description,
            'input_schema': t.schema,
            'strict': true,
          },
      ],
    );
    _messages.add({'role': 'assistant', 'content': res.content});
    return AgentStep(
      text: res.text.trim(),
      calls: res.stopReason == 'tool_use'
          ? [
              for (final u in res.toolUses)
                ToolCall(
                  id: u['id'] as String,
                  name: u['name'] as String,
                  args:
                      (u['input'] as Map?)?.cast<String, Object?>() ?? const {},
                ),
            ]
          : const [],
    );
  }

  @override
  void addToolResults(List<ToolResult> results) => _messages.add({
    'role': 'user',
    'content': [
      for (final r in results)
        {
          'type': 'tool_result',
          'tool_use_id': r.call.id,
          'content': r.output,
          if (r.isError) 'is_error': true,
        },
    ],
  });

  static const _schema = {
    'type': 'json_schema',
    'schema': {
      'type': 'object',
      'properties': {
        'is_food': {'type': 'boolean'},
        'items': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'food_id': {
                'anyOf': [
                  {'type': 'integer'},
                  {'type': 'null'},
                ],
              },
              'name': {'type': 'string'},
              'grams': {'type': 'number'},
              'confidence': {
                'type': 'string',
                'enum': ['low', 'medium', 'high'],
              },
            },
            'required': ['food_id', 'name', 'grams', 'confidence'],
            'additionalProperties': false,
          },
        },
        'note': {'type': 'string'},
      },
      'required': ['is_food', 'items', 'note'],
      'additionalProperties': false,
    },
  };

  @override
  Future<String> scanJson({
    required String system,
    required Uint8List image,
    required String mediaType,
  }) async {
    final msg = await _client.create(
      system: system,
      messages: [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': base64Encode(image),
              },
            },
            {'type': 'text', 'text': 'Analiza este plato.'},
          ],
        },
      ],
      outputFormat: _schema,
      maxTokens: 4000,
    );
    return msg.text;
  }
}

// ------------------------------------------------------------------ Gemini

class GeminiBackend implements AiBackend {
  GeminiBackend(this._client, {this.label = 'Gemini'});
  final GeminiClient _client;
  final List<Map<String, Object?>> _contents = [];
  int _callSeq = 0;

  @override
  final String label;

  @override
  void addUserText(String text) => _contents.add({
    'role': 'user',
    'parts': [
      {'text': text},
    ],
  });

  static Map<String, Object?> _declaration(ToolSpec t) {
    final props = (t.schema['properties'] as Map?) ?? const {};
    return {
      'name': t.name,
      'description': t.description,
      // Gemini no acepta un objeto sin propiedades: sin argumentos, se omite.
      if (props.isNotEmpty) 'parameters': toGeminiSchema(t.schema),
    };
  }

  @override
  Future<AgentStep> step({
    required String system,
    required List<ToolSpec> tools,
  }) async {
    final res = await _client.generate({
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
      'contents': _contents,
      if (tools.isNotEmpty)
        'tools': [
          {
            'functionDeclarations': [for (final t in tools) _declaration(t)],
          },
        ],
    });
    _contents.add(res.content);
    return AgentStep(
      text: res.text.trim(),
      calls: [
        for (final c in res.functionCalls)
          ToolCall(id: 'call_${_callSeq++}', name: c.name, args: c.args),
      ],
    );
  }

  @override
  void addToolResults(List<ToolResult> results) => _contents.add({
    'role': 'user',
    'parts': [
      for (final r in results)
        {
          'functionResponse': {
            'name': r.call.name,
            'response': _responseObject(r),
          },
        },
    ],
  });

  /// Gemini pide un objeto como respuesta de la función.
  static Map<String, Object?> _responseObject(ToolResult r) {
    if (r.isError) return {'error': r.output};
    try {
      final v = jsonDecode(r.output);
      return v is Map<String, Object?> ? v : {'result': v};
    } on FormatException {
      return {'result': r.output};
    }
  }

  static const _schema = {
    'type': 'OBJECT',
    'properties': {
      'is_food': {'type': 'BOOLEAN'},
      'items': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'food_id': {'type': 'INTEGER', 'nullable': true},
            'name': {'type': 'STRING'},
            'grams': {'type': 'NUMBER'},
            'confidence': {
              'type': 'STRING',
              'enum': ['low', 'medium', 'high'],
            },
          },
          'required': ['food_id', 'name', 'grams', 'confidence'],
        },
      },
      'note': {'type': 'STRING'},
    },
    'required': ['is_food', 'items', 'note'],
  };

  @override
  Future<String> scanJson({
    required String system,
    required Uint8List image,
    required String mediaType,
  }) async {
    final res = await _client.generate({
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'inlineData': {
                'mimeType': mediaType,
                'data': base64Encode(image),
              },
            },
            {'text': 'Analiza este plato.'},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': _schema,
        'temperature': 0.2,
      },
    });
    return res.text;
  }
}
