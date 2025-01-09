// widgets/personal_info_form.dart
import 'package:flutter/material.dart';

class PersonalInfoForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String firstName;
  final String lastName;
  final String goal;
  final String gender;
  final List<String> seeking;
  final String relationshipGoal;
  final ValueChanged<String> onFirstNameChanged;
  final ValueChanged<String> onLastNameChanged;
  final ValueChanged<String?> onGoalChanged;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<String?> onRelationshipGoalChanged;
  final ValueChanged<bool> onSeekingSelectionChanged;

  const PersonalInfoForm({
    Key? key,
    required this.formKey,
    required this.firstName,
    required this.lastName,
    required this.goal,
    required this.gender,
    required this.seeking,
    required this.relationshipGoal,
    required this.onFirstNameChanged,
    required this.onLastNameChanged,
    required this.onGoalChanged,
    required this.onGenderChanged,
    required this.onRelationshipGoalChanged,
    required this.onSeekingSelectionChanged,
  }) : super(key: key);

  Widget _buildTextField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
    required String validatorMsg,
  }) {
    return TextFormField(
      initialValue: initialValue,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(12.0),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? validatorMsg : null,
      onChanged: onChanged,
      cursorColor: Colors.white,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String validatorMsg,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      style: const TextStyle(color: Colors.white),
      selectedItemBuilder: (BuildContext context) {
        return items.map<Widget>((String item) {
          return Text(item, style: const TextStyle(color: Colors.white));
        }).toList();
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(12.0),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      items: items.map((String option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(option, style: const TextStyle(color: Colors.black)),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) =>
          (value == null || value.isEmpty) ? validatorMsg : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color.fromRGBO(64, 65, 65, 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              _buildTextField(
                label: 'Nombre',
                initialValue: firstName,
                onChanged: onFirstNameChanged,
                validatorMsg: 'Por favor ingresa tu nombre',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Apellido',
                initialValue: lastName,
                onChanged: onLastNameChanged,
                validatorMsg: 'Por favor ingresa tu apellido',
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                label: 'Objetivo',
                value: goal.isNotEmpty ? goal : null,
                items: const ['Definición', 'Volumen', 'Mantenimiento'],
                onChanged: onGoalChanged,
                validatorMsg: 'Por favor selecciona tu objetivo',
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                label: 'Género',
                value: gender.isNotEmpty ? gender : null,
                items: const [
                  'Masculino',
                  'Femenino',
                  'No Binario',
                  'Prefiero no decirlo',
                  'Otro'
                ],
                onChanged: onGenderChanged,
                validatorMsg: 'Por favor selecciona tu género',
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Buscando:',
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10.0,
                children: [
                  'Masculino',
                  'Femenino',
                  'No Binario',
                  'Prefiero no decirlo',
                  'Otro'
                ].map((option) {
                  final selected = seeking.contains(option);
                  return FilterChip(
                    label: Text(option,
                        style: const TextStyle(color: Colors.black)),
                    selected: selected,
                    backgroundColor: Colors.white54,
                    selectedColor: Colors.white,
                    onSelected: (bool isSelected) {
                      onSeekingSelectionChanged(isSelected);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                label: 'Objetivo de Relación',
                value: relationshipGoal.isNotEmpty ? relationshipGoal : null,
                items: const ['Amistad', 'Relación', 'Casual', 'Otro'],
                onChanged: onRelationshipGoalChanged,
                validatorMsg: 'Por favor selecciona un objetivo de relación',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
