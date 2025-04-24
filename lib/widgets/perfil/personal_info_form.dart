import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

/// Evita más de un salto de línea
class TwoLineTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final newlineCount = '\n'.allMatches(newValue.text).length;
    return (newlineCount > 1) ? oldValue : newValue;
  }
}

/// Campo de biografía con contador
class BiographyTextField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const BiographyTextField({
    Key? key,
    required this.initialValue,
    required this.onChanged,
  }) : super(key: key);

  @override
  _BiographyTextFieldState createState() => _BiographyTextFieldState();
}

class _BiographyTextFieldState extends State<BiographyTextField> {
  late TextEditingController _controller;
  final int maxChars = 80;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(() {
      widget.onChanged(_controller.text);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
          decoration: InputDecoration(
            labelText: tr('biography_label'),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            filled: true,
            fillColor: Colors.white12,
            labelStyle: const TextStyle(color: Colors.white70),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white54),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.blueAccent),
              borderRadius: BorderRadius.circular(12),
            ),
            errorStyle: const TextStyle(color: Colors.redAccent),
          ),
          inputFormatters: [
            TwoLineTextInputFormatter(),
            LengthLimitingTextInputFormatter(maxChars),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tr('characters_count', namedArgs: {'count': _controller.text.length.toString(), 'max': maxChars.toString()}),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

/// Formulario con el resto de campos
class PersonalInfoForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String firstName;
  final String lastName;
  final String goal;
  final String gender;
  final List<String> seeking;
  final String relationshipGoal;
  final String biography;
  final int age;
  final int height;
  final int weight;

  final ValueChanged<String> onFirstNameChanged;
  final ValueChanged<String> onLastNameChanged;
  final ValueChanged<String?> onGoalChanged;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<String?> onRelationshipGoalChanged;
  final ValueChanged<String> onBiographyChanged;
  final ValueChanged<int> onAgeChanged;
  final ValueChanged<int> onHeightChanged;
  final ValueChanged<int> onWeightChanged;
  final Function(String, bool) onSeekingSelectionChanged;

  const PersonalInfoForm({
    Key? key,
    required this.formKey,
    required this.firstName,
    required this.lastName,
    required this.goal,
    required this.gender,
    required this.seeking,
    required this.relationshipGoal,
    required this.biography,
    required this.age,
    required this.height,
    required this.weight,
    required this.onFirstNameChanged,
    required this.onLastNameChanged,
    required this.onGoalChanged,
    required this.onGenderChanged,
    required this.onRelationshipGoalChanged,
    required this.onBiographyChanged,
    required this.onAgeChanged,
    required this.onHeightChanged,
    required this.onWeightChanged,
    required this.onSeekingSelectionChanged,
  }) : super(key: key);

  Widget _buildTextField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
    required String validatorMsg,
    int maxLines = 1,
  }) {
    return TextFormField(
      initialValue: initialValue,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: Colors.white12,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueAccent),
          borderRadius: BorderRadius.circular(12),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      validator: (v) => (v == null || v.isEmpty) ? validatorMsg : null,
      onChanged: onChanged,
      cursorColor: Colors.white,
    );
  }

  Widget _buildNumericField({
    required String label,
    required int initialValue,
    required ValueChanged<int> onChanged,
    required String validatorMsg,
    int? min,
    int? max,
  }) {
    return TextFormField(
      initialValue: initialValue.toString(),
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: Colors.white12,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueAccent),
          borderRadius: BorderRadius.circular(12),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return validatorMsg;
        final n = int.tryParse(v);
        if (n == null) return tr('please_enter_valid_number');
        if ((min != null && n < min) || (max != null && n > max)) {
          return tr('value_between_range', namedArgs: {'min': min.toString(), 'max': max.toString()});
        }
        return null;
      },
      onChanged: (v) {
        final n = int.tryParse(v);
        if (n != null) onChanged(n);
      },
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
  }

  // Mapeo de valores traducidos a valores internos para los menús desplegables
  Map<String, String> _getValueMap(String type) {
    if (type == 'fitness') {
      return {
        tr('general_option'): 'General',
        tr('definition_option'): 'Definición',
        tr('volume_option'): 'Volumen',
        tr('maintenance_option'): 'Mantenimiento',
      };
    } else if (type == 'relationship') {
      return {
        tr('friendship_option'): 'Amistad',
        tr('dating_option'): 'Citas',
        tr('serious_relationship_option'): 'Relación seria',
        tr('casual_option'): 'Casual',
        tr('not_sure_option'): 'No estoy seguro',
      };
    } else if (type == 'gender') {
      return {
        tr('male_option'): 'Masculino',
        tr('female_option'): 'Femenino',
        tr('non_binary_option'): 'No Binario',
        tr('prefer_not_to_say_option'): 'Prefiero no decirlo',
        tr('other_gender_option'): 'Otro',
      };
    }
    return {};
  }

  // Obtener la clave traducida a partir del valor interno
  String? _getTranslatedKey(String? value, String type) {
    if (value == null) return null;
    
    final map = _getValueMap(type);
    for (var entry in map.entries) {
      if (entry.value == value) {
        return entry.key;
      }
    }
    return null;
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String validatorMsg,
    required String type,
  }) {
    // Convertir el valor interno al valor traducido para mostrar
    final translatedValue = _getTranslatedKey(value, type);
    
    return DropdownButtonFormField<String>(
      value: translatedValue,
      style: const TextStyle(color: Colors.white),
      dropdownColor: Colors.grey[800],
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: Colors.white12,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueAccent),
          borderRadius: BorderRadius.circular(12),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      items: items
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          // Convertir el valor traducido al valor interno antes de pasarlo al callback
          final internalValue = _getValueMap(type)[newValue];
          onChanged(internalValue);
        } else {
          onChanged(null);
        }
      },
      validator: (v) => (v == null || v.isEmpty) ? validatorMsg : null,
      selectedItemBuilder: (ctx) =>
          items.map((o) => Text(o, style: const TextStyle(color: Colors.white))).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sectionHeaderStyle = TextStyle(
      color: Colors.white70,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );

    return Card(
      color: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              // Nombre / Apellido en fila
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: tr('first_name_label'),
                      initialValue: firstName,
                      onChanged: onFirstNameChanged,
                      validatorMsg: tr('please_enter_first_name_error'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      label: tr('last_name_label'),
                      initialValue: lastName,
                      onChanged: onLastNameChanged,
                      validatorMsg: tr('please_enter_last_name_error'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Encabezado Objetivos
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('objectives_section'), style: sectionHeaderStyle),
              ),
              const SizedBox(height: 8),
              // Objetivo fitness + Objetivo de Relación
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownField(
                      label: tr('fitness_goal_label'),
                      value: goal.isNotEmpty ? goal : null,
                      items: [tr('general_option'), tr('definition_option'), tr('volume_option'), tr('maintenance_option')],
                      onChanged: onGoalChanged,
                      validatorMsg: tr('please_select_goal_error'),
                      type: 'fitness',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdownField(
                      label: tr('relationship_goal_label'),
                      value: relationshipGoal.isNotEmpty ? relationshipGoal : null,
                      items: [
                        tr('friendship'),
                        tr('relationship'),
                        tr('casual'),
                        tr('other')
                      ],
                      onChanged: onRelationshipGoalChanged,
                      validatorMsg: tr('please_select_relationship_goal_error'),
                      type: 'relationship',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Género
              _buildDropdownField(
                label: tr('gender_label'),
                value: gender.isNotEmpty ? gender : null,
                items: [
                  tr('male_option'),
                  tr('female_option'),
                  tr('non_binary_option'),
                  tr('prefer_not_to_say_option'),
                  tr('other_gender_option')
                ],
                onChanged: onGenderChanged,
                validatorMsg: tr('please_select_gender_error'),
                type: 'gender',
              ),
              const SizedBox(height: 16),

              // Buscando
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr('looking_for_label'),
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [tr('male_option'), tr('female_option'), tr('non_binary_option'), tr('prefer_not_to_say_option'), tr('other_gender_option')]
                    .map((opt) {
                  final sel = seeking.contains(opt);
                  return FilterChip(
                    label: Text(opt, style: TextStyle(color: sel ? Colors.black : Colors.white)),
                    selected: sel,
                    backgroundColor: Colors.transparent,
                    selectedColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    onSelected: (b) => onSeekingSelectionChanged(opt, b),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Edad, Altura, Peso
              _buildNumericField(
                label: tr('age_label'),
                initialValue: age,
                onChanged: onAgeChanged,
                validatorMsg: tr('please_enter_age_error'),
                min: 18,
                max: 100,
              ),
              const SizedBox(height: 16),
              _buildNumericField(
                label: tr('height_label'),
                initialValue: height,
                onChanged: onHeightChanged,
                validatorMsg: tr('please_enter_height_error'),
                min: 120,
                max: 250,
              ),
              const SizedBox(height: 16),
              _buildNumericField(
                label: tr('weight_label'),
                initialValue: weight,
                onChanged: onWeightChanged,
                validatorMsg: tr('please_enter_weight_error'),
                min: 30,
                max: 250,
              ),
              const SizedBox(height: 16),

              // Biografía
              BiographyTextField(
                initialValue: biography,
                onChanged: onBiographyChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
