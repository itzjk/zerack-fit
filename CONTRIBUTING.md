# Cómo contribuir

1. **Sin fuente no hay regla.** Cualquier fórmula, constante o regla nueva
   necesita una `Source` en `packages/zerack_core/lib/src/source.dart` y una
   fila en `SOURCES.md`. Si no hay fuente publicada, no entra.
2. **Lo médico se queda fuera.** La app no diagnostica ni trata. Cualquier
   texto que lo sugiera se rechaza.
3. **Local-first.** Nada sale del teléfono salvo en funciones que la persona
   activa (IA, código de barras) y que dicen qué envían.
4. **Pruebas.** Todo cambio en el núcleo o en el estado lleva pruebas. Antes de
   abrir un PR:

```bash
cd packages/zerack_core && dart format . && dart analyze --fatal-infos && dart test
cd apps/zerack_fit && dart format lib test && flutter analyze && flutter test
```

5. **Compara identificadores, no textos.** El motor usa enums; la redacción
   vive en `apps/zerack_fit/lib/src/ui/strings.dart`.

## Regenerar datos

- Alimentos: descarga SR Legacy CSV de https://fdc.nal.usda.gov/download-datasets
  y corre `python3 tools/foods/build_foods.py <carpeta> apps/zerack_fit/assets/foods_es.json`.
  Para agregar un alimento, agrega su `fdc_id` y nombre a `tools/foods/foods_es.csv`.
- Ícono: `python3 tools/icon/make_icon.py apps/zerack_fit`.
