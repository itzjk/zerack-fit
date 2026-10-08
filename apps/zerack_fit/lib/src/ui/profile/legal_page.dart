import 'package:flutter/material.dart';

enum LegalDoc {
  privacy('Aviso de privacidad', 'assets/legal/privacidad.txt'),
  terms('Términos de uso', 'assets/legal/terminos.txt');

  const LegalDoc(this.title, this.asset);
  final String title;
  final String asset;
}

class LegalPage extends StatelessWidget {
  const LegalPage(this.doc, {super.key});
  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(doc.asset),
        builder: (context, snap) => snap.hasData
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(snap.data!),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
