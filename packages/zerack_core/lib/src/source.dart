/// Referencia publicada que respalda una fórmula, constante o regla.
///
/// Regla del proyecto: nada entra al motor sin una [Source]. Si no hay fuente,
/// no hay regla.
class Source {
  const Source({required this.id, required this.citation, this.url});

  /// Identificador estable, p. ej. `mifflin-1990`. No traducir ni reescribir.
  final String id;

  /// Cita legible (autores, año, revista).
  final String citation;

  final String? url;

  @override
  String toString() => citation;
}

/// Catálogo central de fuentes. Ver también `SOURCES.md` en la raíz.
abstract final class Sources {
  static const mifflin1990 = Source(
    id: 'mifflin-1990',
    citation: 'Mifflin MD, St Jeor ST, et al. A new predictive equation for '
        'resting energy expenditure in healthy individuals. '
        'Am J Clin Nutr. 1990;51(2):241-247.',
    url: 'https://doi.org/10.1093/ajcn/51.2.241',
  );

  static const frankenfield2005 = Source(
    id: 'frankenfield-2005',
    citation: 'Frankenfield D, Roth-Yousey L, Compher C. Comparison of '
        'predictive equations for resting metabolic rate in healthy nonobese '
        'and obese adults: a systematic review. J Am Diet Assoc. '
        '2005;105(5):775-789.',
    url: 'https://doi.org/10.1016/j.jada.2005.02.005',
  );

  static const fao2004 = Source(
    id: 'fao-who-unu-2004',
    citation: 'FAO/WHO/UNU. Human energy requirements. Report of a Joint '
        'Expert Consultation. FAO Food and Nutrition Technical Report Series 1. '
        'Rome, 2004.',
    url: 'https://www.fao.org/4/y5686e/y5686e00.htm',
  );

  static const compendium2024 = Source(
    id: 'compendium-2024',
    citation: 'Herrmann SD, et al. 2024 Adult Compendium of Physical '
        'Activities. J Sport Health Sci. 2024;13(1):6-12.',
    url: 'https://pacompendium.com',
  );

  static const acsmScreening2015 = Source(
    id: 'acsm-screening-2015',
    citation: 'Riebe D, et al. Updating ACSM\'s recommendations for exercise '
        'preparticipation health screening. Med Sci Sports Exerc. '
        '2015;47(11):2473-2479.',
    url: 'https://doi.org/10.1249/MSS.0000000000000664',
  );

  static const acsmProgression2009 = Source(
    id: 'acsm-progression-2009',
    citation: 'American College of Sports Medicine. Position stand: '
        'Progression models in resistance training for healthy adults. '
        'Med Sci Sports Exerc. 2009;41(3):687-708.',
    url: 'https://doi.org/10.1249/MSS.0b013e3181915670',
  );

  static const tanaka2001 = Source(
    id: 'tanaka-2001',
    citation: 'Tanaka H, Monahan KD, Seals DR. Age-predicted maximal heart '
        'rate revisited. J Am Coll Cardiol. 2001;37(1):153-156.',
    url: 'https://doi.org/10.1016/S0735-1097(00)01054-8',
  );

  static const acsmGuidelines = Source(
    id: 'acsm-getp',
    citation: 'American College of Sports Medicine. ACSM\'s Guidelines for '
        'Exercise Testing and Prescription. 11th ed. Wolters Kluwer; 2021.',
  );

  static const hooper1995 = Source(
    id: 'hooper-1995',
    citation: 'Hooper SL, Mackinnon LT. Monitoring overtraining in athletes. '
        'Recommendations. Sports Med. 1995;20(5):321-327.',
    url: 'https://doi.org/10.2165/00007256-199520050-00003',
  );

  static const acsmWeightLoss2001 = Source(
    id: 'acsm-weight-loss-2001',
    citation: 'Jakicic JM, et al. American College of Sports Medicine '
        'position stand: Appropriate intervention strategies for weight loss '
        'and prevention of weight regain for adults. Med Sci Sports Exerc. '
        '2001;33(12):2145-2156.',
    url: 'https://doi.org/10.1097/00005768-200112000-00026',
  );

  static const issnProtein2017 = Source(
    id: 'issn-protein-2017',
    citation: 'Jäger R, et al. International Society of Sports Nutrition '
        'Position Stand: protein and exercise. J Int Soc Sports Nutr. '
        '2017;14:20.',
    url: 'https://doi.org/10.1186/s12970-017-0177-8',
  );

  static const who2020 = Source(
    id: 'who-2020',
    citation: 'Bull FC, et al. World Health Organization 2020 guidelines on '
        'physical activity and sedentary behaviour. Br J Sports Med. '
        '2020;54(24):1451-1462.',
    url: 'https://doi.org/10.1136/bjsports-2020-102955',
  );

  static const acsmQuantity2011 = Source(
    id: 'acsm-quantity-2011',
    citation: 'Garber CE, et al. American College of Sports Medicine position '
        'stand. Quantity and quality of exercise for developing and '
        'maintaining cardiorespiratory, musculoskeletal, and neuromotor '
        'fitness in apparently healthy adults. Med Sci Sports Exerc. '
        '2011;43(7):1334-1359.',
    url: 'https://doi.org/10.1249/MSS.0b013e318213fefb',
  );

  static const usdaSrLegacy = Source(
    id: 'usda-sr-legacy-2018',
    citation: 'U.S. Department of Agriculture, Agricultural Research Service. '
        'FoodData Central: SR Legacy, April 2018. Dominio público (CC0).',
    url: 'https://fdc.nal.usda.gov',
  );

  /// Todas las fuentes, para mostrarlas en la app.
  static const all = [
    mifflin1990,
    frankenfield2005,
    fao2004,
    compendium2024,
    acsmScreening2015,
    acsmProgression2009,
    acsmQuantity2011,
    acsmWeightLoss2001,
    tanaka2001,
    acsmGuidelines,
    hooper1995,
    issnProtein2017,
    who2020,
    usdaSrLegacy,
  ];
}
