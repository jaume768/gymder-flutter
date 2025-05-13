import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/match_service.dart';

class FilterModalContent extends StatefulWidget {
  final bool hasLocation;
  final RangeValues initialAgeRange;
  final RangeValues initialWeightRange;
  final RangeValues initialHeightRange;
  final String initialGymStage;
  final String initialRelationshipType;
  final bool initialUseLocation;
  final RangeValues initialDistanceRange;

  // Estos son los NUEVOS campos:
  final bool initialFilterByBasics;
  final RangeValues initialSquatRange;
  final RangeValues initialBenchRange;
  final RangeValues initialDeadliftRange;

  const FilterModalContent({
    Key? key,
    required this.hasLocation,
    required this.initialAgeRange,
    required this.initialWeightRange,
    required this.initialHeightRange,
    required this.initialGymStage,
    required this.initialRelationshipType,
    this.initialUseLocation = false,
    this.initialDistanceRange = const RangeValues(5, 50),

    // Y aquí los incoporamos al constructor:
    required this.initialFilterByBasics,
    this.initialSquatRange = const RangeValues(0, 300),
    this.initialBenchRange = const RangeValues(0, 200),
    this.initialDeadliftRange = const RangeValues(0, 400),
  }) : super(key: key);

  @override
  _FilterModalContentState createState() => _FilterModalContentState();
}

class _FilterModalContentState extends State<FilterModalContent> {
  // Rangos principales (ya los tienes)
  late RangeValues ageRange;
  late RangeValues weightRange;
  late RangeValues heightRange;
  late String selectedGymStage;
  late String selectedRelationshipType;
  bool useLocation = false;
  late RangeValues distanceRange;

  // Parámetros de "filtrar por básicos"
  late bool filterByBasics;
  late RangeValues squatRange;
  late RangeValues benchRange;
  late RangeValues deadliftRange;

  // Límites máximos para sliders de básicos
  static const double _maxSquat = 300;
  static const double _maxBench = 200;
  static const double _maxDeadlift = 400;

  @override
  void initState() {
    super.initState();

    // Inicializamos con los valores recibidos desde el padre
    ageRange = widget.initialAgeRange;
    weightRange = widget.initialWeightRange;
    heightRange = widget.initialHeightRange;
    selectedGymStage = widget.initialGymStage;
    selectedRelationshipType = widget.initialRelationshipType;
    useLocation = widget.initialUseLocation;
    distanceRange = widget.initialDistanceRange;

    // ¡Aquí el cambio clave!
    filterByBasics = widget.initialFilterByBasics;
    squatRange = widget.initialSquatRange;
    benchRange = widget.initialBenchRange;
    deadliftRange = widget.initialDeadliftRange;
  }

  @override
  Widget build(BuildContext context) {
    final gymStageMap = {
      'Todos': tr('all'),
      'Mantenimiento': tr('maintenance'),
      'Volumen': tr('volume'),
      'Definición': tr('definition'),
    };
    final relationshipTypeMap = {
      'Todos': tr('all'),
      'Amistad': tr('friendship'),
      'Relación': tr('relationship'),
      'Casual': tr('casual'),
      'Otro': tr('other'),
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRangeSlider(
              label: tr("age_range"),
              values: ageRange,
              min: 18,
              max: 100,
              divisions: 82,
              onChanged: (v) => setState(() => ageRange = v),
            ),

            _buildRangeSlider(
              label: tr("weight_range"),
              values: weightRange,
              min: 40,
              max: 120,
              divisions: 80,
              onChanged: (v) => setState(() => weightRange = v),
            ),

            _buildRangeSlider(
              label: tr("height_range"),
              values: heightRange,
              min: 100,
              max: 250,
              divisions: 150,
              onChanged: (v) => setState(() => heightRange = v),
            ),

            const SizedBox(height: 10),

            _buildDropdown(
              label: tr("gym_stage_filter"),
              value: selectedGymStage,
              items: gymStageMap,
              onChanged: (v) => setState(() => selectedGymStage = v!),
            ),

            _buildDropdown(
              label: tr("relationship_type_filter"),
              value: selectedRelationshipType,
              items: relationshipTypeMap,
              onChanged: (v) => setState(() => selectedRelationshipType = v!),
            ),

            const SizedBox(height: 20),

            if (widget.hasLocation) ...[
              SwitchListTile(
                title: Text(tr("filter_by_location"),
                    style: TextStyle(color: Colors.white)),
                value: useLocation,
                activeColor: Colors.blueAccent,
                onChanged: (v) => setState(() => useLocation = v),
              ),
              if (useLocation)
                _buildRangeSlider(
                  label: tr("distance_km"),
                  values: distanceRange,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (v) => setState(() => distanceRange = v),
                ),
            ],

            const SizedBox(height: 20),
            // Switch: filtrar por básicos
            SwitchListTile(
              title: Text(tr("filter_by_basics"),
                  style: const TextStyle(color: Colors.white)),
              value: filterByBasics,
              activeColor: Colors.blueAccent,
              onChanged: (v) => setState(() => filterByBasics = v),
            ),

            // Si está activo, mostramos sliders de básicos con sus valores guardados
            if (filterByBasics) ...[
              _buildRangeSlider(
                label: tr("squat_kg"),
                values: squatRange,
                min: 0,
                max: _maxSquat,
                divisions: (_maxSquat ~/ 5),
                onChanged: (v) => setState(() => squatRange = v),
              ),
              _buildRangeSlider(
                label: tr("bench_press_kg"),
                values: benchRange,
                min: 0,
                max: _maxBench,
                divisions: (100),
                onChanged: (v) => setState(() => benchRange = v),
              ),
              _buildRangeSlider(
                label: tr("deadlift_kg"),
                values: deadliftRange,
                min: 0,
                max: _maxDeadlift,
                divisions: (_maxDeadlift ~/ 5),
                onChanged: (v) => setState(() => deadliftRange = v),
              ),
            ],

            const SizedBox(height: 20),

            // Botón "Aplicar"
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () async {
                // Construimos el mapa de filtros
                final filters = <String, String>{
                  'ageMin': ageRange.start.round().toString(),
                  'ageMax': ageRange.end.round().toString(),
                  'weightMin': weightRange.start.round().toString(),
                  'weightMax': weightRange.end.round().toString(),
                  'heightMin': heightRange.start.round().toString(),
                  'heightMax': heightRange.end.round().toString(),
                  'gymStage': selectedGymStage,
                  'relationshipGoal': selectedRelationshipType,
                  'useLocation': useLocation.toString(),
                };
                if (useLocation) {
                  filters['distanceMin'] =
                      distanceRange.start.round().toString();
                  filters['distanceMax'] = distanceRange.end.round().toString();
                }

                // Sólo añadimos básicos si el usuario realmente movió el slider
                if (filterByBasics) {
                  if (squatRange.start > 0 || squatRange.end < _maxSquat) {
                    filters['squatMin'] = squatRange.start.round().toString();
                    filters['squatMax'] = squatRange.end.round().toString();
                  }
                  if (benchRange.start > 0 || benchRange.end < _maxBench) {
                    filters['benchMin'] = benchRange.start.round().toString();
                    filters['benchMax'] = benchRange.end.round().toString();
                  }
                  if (deadliftRange.start > 0 ||
                      deadliftRange.end < _maxDeadlift) {
                    filters['deadliftMin'] =
                        deadliftRange.start.round().toString();
                    filters['deadliftMax'] =
                        deadliftRange.end.round().toString();
                  }
                }

                // Llamada al backend
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final token = await auth.getToken();
                if (token != null) {
                  final matchService = MatchService(token: token);
                  final result = await matchService
                      .getSuggestedMatchesWithFilters(filters);
                  if (result['success'] == true) {
                    List<User> matches = (result['matches'] as List)
                        .map((j) => User.fromJson(j))
                        .toList();
                    Navigator.of(context).pop({
                      'matches': matches,
                      'ageRange': ageRange,
                      'weightRange': weightRange,
                      'heightRange': heightRange,
                      'gymStage': selectedGymStage,
                      'relationshipType': selectedRelationshipType,
                      'useLocation': useLocation,
                      'distanceRange': distanceRange,
                      'filterByBasics': filterByBasics,
                      'squatRange': squatRange,
                      'benchRange': benchRange,
                      'deadliftRange': deadliftRange,
                    });
                    return;
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(result['message'] ??
                              tr("error_fetching_more_users"))),
                    );
                  }
                }

                Navigator.of(context).pop();
              },
              child: Text(tr("apply"),
                  style: const TextStyle(color: Colors.black)),
            ),

            const SizedBox(height: 10),

            // Botón "Quitar filtros"
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                padding:
                const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => Navigator.of(context).pop({'remove': true}),
              child: Text(tr("remove_filter"),
                  style: const TextStyle(color: Colors.white)),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSlider({
    required String label,
    required RangeValues values,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<RangeValues> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        RangeSlider(
          values: values,
          min: min,
          max: max,
          divisions: divisions,
          labels: RangeLabels(
            values.start.round().toString(),
            values.end.round().toString(),
          ),
          activeColor: Colors.blueAccent,
          inactiveColor: Colors.grey,
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(10)),
          child: DropdownButton<String>(
            value: value,
            dropdownColor: Colors.grey[850],
            style: const TextStyle(color: Colors.white),
            isExpanded: true,
            underline: const SizedBox(),
            items: items.entries
                .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}