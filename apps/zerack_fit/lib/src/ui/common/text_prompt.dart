import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Diálogo con un campo de texto. El controlador vive con el diálogo, así que
/// sigue vivo durante la animación de cierre.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  String? label,
  String? hint,
  String? initial,
  String? suffix,
  String confirm = 'Guardar',
  bool secret = false,
  bool decimal = false,
  int maxLines = 1,
  Key? fieldKey,
  Key? confirmKey,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPrompt(
    title: title,
    label: label,
    hint: hint,
    initial: initial,
    suffix: suffix,
    confirm: confirm,
    secret: secret,
    decimal: decimal,
    maxLines: maxLines,
    fieldKey: fieldKey,
    confirmKey: confirmKey,
  ),
);

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.confirm,
    required this.secret,
    required this.decimal,
    required this.maxLines,
    this.label,
    this.hint,
    this.initial,
    this.suffix,
    this.fieldKey,
    this.confirmKey,
  });

  final String title;
  final String? label;
  final String? hint;
  final String? initial;
  final String? suffix;
  final String confirm;
  final bool secret;
  final bool decimal;
  final int maxLines;
  final Key? fieldKey;
  final Key? confirmKey;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: widget.fieldKey,
        controller: _ctrl,
        autofocus: true,
        obscureText: widget.secret,
        maxLines: widget.secret ? 1 : widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          suffixText: widget.suffix,
        ),
        keyboardType: widget.decimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        inputFormatters: widget.decimal
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
            : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: widget.confirmKey,
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
