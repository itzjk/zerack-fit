/// Ejercicio del catálogo base. El `id` es estable: los registros lo guardan.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.targetReps = 10,
    this.smallestStepKg = 2.5,
  });

  final String id;
  final String name;

  /// ACSM 2009 recomienda 8–12 repeticiones para principiantes e intermedios.
  final int targetReps;
  final double smallestStepKg;
}

const exerciseCatalog = <Exercise>[
  Exercise(id: 'back_squat', name: 'Sentadilla con barra'),
  Exercise(id: 'bench_press', name: 'Press de banca'),
  Exercise(id: 'romanian_deadlift', name: 'Peso muerto rumano'),
  Exercise(id: 'barbell_row', name: 'Remo con barra'),
  Exercise(id: 'overhead_press', name: 'Press militar'),
  Exercise(id: 'lat_pulldown', name: 'Jalón al pecho'),
  Exercise(id: 'leg_press', name: 'Prensa de piernas', smallestStepKg: 5),
  Exercise(id: 'dumbbell_curl', name: 'Curl con mancuernas', smallestStepKg: 1),
];

Exercise exerciseById(String id) =>
    exerciseCatalog.firstWhere((e) => e.id == id);
