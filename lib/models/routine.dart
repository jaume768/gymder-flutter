class Exercise {
  final String name;
  final int series;
  final int repetitions;
  String? id; // Opcional para cuando se recibe de la API

  Exercise({
    required this.name,
    required this.series,
    required this.repetitions,
    this.id,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'] ?? '',
      series: json['series'] ?? 0,
      repetitions: json['repetitions'] ?? 0,
      id: json['_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'series': series,
      'repetitions': repetitions,
      if (id != null) '_id': id,
    };
  }

  String get seriesReps => '${series}x$repetitions';
}

class Routine {
  final String? id;
  final String name;
  final List<Exercise> exercises;
  final String? userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Routine({
    this.id,
    required this.name,
    required this.exercises,
    this.userId,
    this.createdAt,
    this.updatedAt,
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['_id'],
      name: json['name'] ?? '',
      exercises: json['exercises'] != null
          ? List<Exercise>.from(
              json['exercises'].map((x) => Exercise.fromJson(x)))
          : [],
      userId: json['userId'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'name': name,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      if (userId != null) 'userId': userId,
    };
  }
}
