import 'package:flutter/material.dart';
import '../../models/routine.dart';
import 'package:easy_localization/easy_localization.dart';

class ReadOnlyRoutineCard extends StatelessWidget {
  final Routine routine;

  const ReadOnlyRoutineCard({
    Key? key,
    required this.routine,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10.0),
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre de la rutina
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              routine.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          
          // Línea divisoria
          const Divider(height: 1, color: Colors.grey),
          
          // Lista de ejercicios
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
            ),
            child: Column(
              children: routine.exercises.asMap().entries.map((entry) {
                final int idx = entry.key;
                final Exercise exercise = entry.value;
                return Column(
                  children: [
                    if (idx > 0)
                      Divider(
                        height: 1,
                        color: Colors.grey.withOpacity(0.2),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12.0,
                        horizontal: 16.0,
                      ),
                      child: Table(
                        columnWidths: const {
                          0: FixedColumnWidth(24), // número fijo
                          1: FixedColumnWidth(12), // espacio
                          2: FlexColumnWidth(1), // nombre expande
                          3: FixedColumnWidth(12), // espacio
                          4: FixedColumnWidth(1), // línea divisora
                          5: FixedColumnWidth(12), // espacio
                          6: FixedColumnWidth(60), // series x repeticiones ancho fijo
                        },
                        children: [
                          TableRow(
                            children: [
                              // 0: número de ejercicio
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black, width: 1.5),
                                ),
                                child: Center(
                                  child: Text(
                                    '${idx + 1}',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),

                              // 1: espacio
                              const SizedBox(),

                              // 2: nombre del ejercicio
                              Text(
                                exercise.name,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),

                              // 3: espacio
                              const SizedBox(),

                              // 4: línea divisora
                              Container(
                                height: 24,
                                width: 1,
                                color: Colors.grey.withOpacity(0.5),
                              ),

                              // 5: espacio
                              const SizedBox(),

                              // 6: series x repeticiones
                              SizedBox(
                                width: 60,
                                child: Text(
                                  exercise.seriesReps,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
