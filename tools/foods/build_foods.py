"""Genera la base de alimentos de la app a partir del USDA FoodData Central.

Uso:
    python3 tools/foods/build_foods.py <carpeta SR Legacy CSV> <salida.json>

Fuente: USDA FoodData Central, SR Legacy (abril 2018), dominio público (CC0).
https://fdc.nal.usda.gov/download-datasets

Los valores nutricionales se copian tal cual del USDA; este script solo agrega
el nombre en español de `foods_es.csv` y traduce las porciones comunes. Si un
fdc_id no existe o le falta la energía, el script falla en lugar de adivinar.
"""

import csv
import json
import sys
from pathlib import Path

NUTRIENTS = {
    "1008": "kcal",
    "1003": "protein",
    "1004": "fat",
    "1005": "carbs",
    "1079": "fiber",
}
REQUIRED = {"kcal", "protein", "fat", "carbs"}

# Unidad de porción del USDA (primer tramo del modificador) → español.
PORTIONS = {
    "cup": "taza",
    "cup chopped": "taza picada",
    "cup slices": "taza en rebanadas",
    "cup pieces": "taza en trozos",
    "cup (8 fl oz)": "taza (240 ml)",
    "oz": "onza (28 g)",
    "fl oz": "onza líquida",
    "slice": "rebanada",
    "tbsp": "cucharada",
    "tsp": "cucharadita",
    "large": "pieza grande",
    "medium": "pieza mediana",
    "small": "pieza chica",
    "fruit": "pieza",
    "can": "lata",
    "can or bottle (12 fl oz)": "lata (355 ml)",
    "drink": "bebida",
    "bar": "barra",
    "tortilla": "tortilla",
    "each taco": "taco",
    "enchilada": "enchilada",
    "tamale": "tamal",
    "doughnut": "dona",
    "cookie": "galleta",
    "cracker": "galleta",
    "fillet": "filete",
    "steak": "bistec",
    "chop": "chuleta",
    "date": "dátil",
    "cherry": "cereza",
    "nlea serving": "porción",
}


def _fmt_amount(a: float) -> str:
    return str(int(a)) if a == int(a) else f"{a:g}"


def build(src: Path, mapping: Path) -> list[dict]:
    foods = {r["fdc_id"]: r for r in csv.DictReader(open(src / "food.csv"))}
    wanted = list(csv.DictReader(open(mapping, encoding="utf-8")))
    ids = {w["fdc_id"] for w in wanted}
    if len(ids) != len(wanted):
        sys.exit("fdc_id repetido en el mapeo")

    nutrients: dict[str, dict[str, float]] = {i: {} for i in ids}
    for r in csv.DictReader(open(src / "food_nutrient.csv")):
        if r["fdc_id"] in ids and r["nutrient_id"] in NUTRIENTS:
            nutrients[r["fdc_id"]][NUTRIENTS[r["nutrient_id"]]] = float(r["amount"])

    units = {r["id"]: r["name"] for r in csv.DictReader(open(src / "measure_unit.csv"))}
    portions: dict[str, list[list]] = {i: [] for i in ids}
    for r in csv.DictReader(open(src / "food_portion.csv")):
        fid = r["fdc_id"]
        if fid not in ids:
            continue
        unit = units.get(r["measure_unit_id"], "")
        unit = "" if unit == "undetermined" else unit
        mod = r["modifier"].strip().lower()
        key = f"{unit} {mod}".strip() if unit else mod.split(",")[0].strip()
        es = PORTIONS.get(key)
        if not es:
            continue
        label = f"{_fmt_amount(float(r['amount']))} {es}"
        grams = round(float(r["gram_weight"]), 1)
        if grams > 0 and all(p[0] != label for p in portions[fid]):
            portions[fid].append([label, grams])

    out = []
    for w in wanted:
        fid = w["fdc_id"]
        if fid not in foods:
            sys.exit(f"fdc_id {fid} no existe en el USDA")
        n = nutrients[fid]
        missing = REQUIRED - n.keys()
        if missing:
            sys.exit(f"fdc_id {fid} sin {missing}")
        out.append({
            "id": int(fid),
            "name": w["nombre"],
            "category": w["categoria"],
            "aliases": [a for a in w["alias"].split() if a],
            "usda": foods[fid]["description"],
            "per100g": {k: n[k] for k in NUTRIENTS.values() if k in n},
            "portions": portions[fid][:4],
        })
    return out


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    data = build(src, Path(__file__).with_name("foods_es.csv"))
    payload = {
        "source": "USDA FoodData Central, SR Legacy (2018-04), CC0",
        "url": "https://fdc.nal.usda.gov",
        "foods": data,
    }
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    print(f"{len(data)} alimentos → {dst}")


if __name__ == "__main__":
    main()
