import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/models.dart';
import '../../data/off_client.dart';
import '../../services.dart';
import '../common/portion_sheet.dart';
import '../scope.dart';

/// Escanea el código de barras de un producto empacado y busca sus datos en
/// Open Food Facts. Solo el número del código sale del teléfono.
class BarcodePage extends StatefulWidget {
  const BarcodePage({super.key, this.showCamera = true});

  /// En pruebas y en web se usa solo la captura manual.
  final bool showCamera;

  @override
  State<BarcodePage> createState() => _BarcodePageState();
}

class _BarcodePageState extends State<BarcodePage> {
  final _manual = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _lookup(String code) async {
    if (_busy) return;
    if (!OpenFoodFactsClient.isValidBarcode(code)) {
      setState(() => _message = 'El código debe tener de 8 a 14 dígitos.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final food = await ServicesScope.of(context).openFoodFacts.lookup(code);
      if (!mounted) return;
      if (food == null) {
        setState(
          () => _message =
              'No encontré ese producto en Open Food Facts, o no trae '
              'calorías. Anótalo a mano.',
        );
        return;
      }
      setState(() => _busy = false);
      final grams = await showPortionSheet(
        context,
        food,
        initialGrams: food.portions.isEmpty ? 100 : food.portions.first.grams,
        sourceNote: 'Open Food Facts (datos de la comunidad, ODbL)',
      );
      if (grams == null || !mounted) return;
      await AppScope.of(
        context,
      ).addFoodFromDb(food, grams, source: FoodSource.openFoodFacts);
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() => _message = 'No pude consultar. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Código de barras')),
      body: Column(
        children: [
          if (widget.showCamera)
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final code = capture.barcodes
                      .map((b) => b.rawValue)
                      .whereType<String>()
                      .firstOrNull;
                  if (code != null) _lookup(code);
                },
                errorBuilder: (_, _) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No pude abrir la cámara. Escribe el código abajo.',
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_message!, key: const Key('barcode-message')),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('barcode-manual'),
                        controller: _manual,
                        decoration: const InputDecoration(
                          labelText: 'O escribe el código',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    IconButton.filled(
                      key: const Key('barcode-search'),
                      onPressed: () => _lookup(_manual.text.trim()),
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Datos de Open Food Facts, capturados por la comunidad.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
