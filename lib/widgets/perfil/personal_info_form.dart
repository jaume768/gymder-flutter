import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// InputFormatter que evita que se inserten más de un salto de línea (dos líneas).
class TwoLineTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Cuenta el número de saltos de línea en el nuevo valor.
    final newlineCount = '\n'.allMatches(newValue.text).length;
    // Permite máximo 1 salto de línea (2 líneas).
    if (newlineCount > 1) {
      return oldValue;
    }
    return newValue;
  }
}

/// Widget para el campo de biografía que incluye un contador de caracteres.
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
          textAlign: TextAlign.left,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Biografía',
            labelStyle: const TextStyle(color: Colors.white70),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white54),
              borderRadius: BorderRadius.circular(12.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.blueAccent),
              borderRadius: BorderRadius.circular(12.0),
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
          '${_controller.text.length}/$maxChars caracteres',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class PersonalInfoForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String firstName;
  final String lastName;
  final String goal;
  final String gender;
  final List<String> seeking;
  final String relationshipGoal;
  final String biography; // Biografía
  final int age; // Edad
  final int height; // Altura en cm
  final int weight; // Peso en kg

  final ValueChanged<String> onFirstNameChanged;
  final ValueChanged<String> onLastNameChanged;
  final ValueChanged<String?> onGoalChanged;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<String?> onRelationshipGoalChanged;
  final ValueChanged<String> onBiographyChanged; // Callback para biografía
  final ValueChanged<int> onAgeChanged; // Callback para edad
  final ValueChanged<int> onHeightChanged; // Callback para altura
  final ValueChanged<int> onWeightChanged; // Callback para peso

  // CAMBIO: se pasa la opción y el bool para el filtro "Buscando"
  final Function(String option, bool isSelected) onSeekingSelectionChanged;

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
    required this.age, // Edad
    required this.height, // Altura
    required this.weight, // Peso
    required this.onFirstNameChanged,
    required this.onLastNameChanged,
    required this.onGoalChanged,
    required this.onGenderChanged,
    required this.onRelationshipGoalChanged,
    required this.onBiographyChanged,
    required this.onAgeChanged, // Callback para edad
    required this.onHeightChanged, // Callback para altura
    required this.onWeightChanged, // Callback para peso
    required this.onSeekingSelectionChanged,
  }) : super(key: key);

  Widget _buildTextField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
    required String validatorMsg,
    int maxLines = 1,
    TextAlign textAlign = TextAlign.left,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      initialValue: initialValue,
      style: const TextStyle(color: Colors.white),
      textAlign: textAlign,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueAccent),
          borderRadius: BorderRadius.circular(12.0),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? validatorMsg : null,
      onChanged: onChanged,
      cursorColor: Colors.white,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
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
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueAccent),
          borderRadius: BorderRadius.circular(12.0),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return validatorMsg;
        }
        final intValue = int.tryParse(value);
        if (intValue == null) {
          return 'Por favor, ingresa un número válido';
        }
        if (min != null && intValue < min) {
          return 'El valor mínimo es $min';
        }
        if (max != null && intValue > max) {
          return 'El valor máximo es $max';
        }
        return null;
      },
      onChanged: (value) {
        final intValue = int.tryParse(value);
        if (intValue != null) {
          onChanged(intValue);
        }
      },
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
      dropdownColor: Colors.grey[800],
      selectedItemBuilder: (BuildContext context) {
        return items.map<Widget>((String item) {
          return Text(item, style: const TextStyle(color: Colors.white));
        }).toList();
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueAccent),
          borderRadius: BorderRadius.circular(12.0),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      items: items.map((String option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(option, style: const TextStyle(color: Colors.white)),
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
      color: const Color.fromRGBO(20, 20, 20, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(4),
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
              // Sección "Buscando"
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Buscando:',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9), fontSize: 16),
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
                        style: TextStyle(
                            color: selected ? Colors.black : Colors.white)),
                    selected: selected,
                    backgroundColor: Colors.grey[900],
                    selectedColor: Colors.blueAccent,
                    onSelected: (bool isSelected) {
                      onSeekingSelectionChanged(option, isSelected);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                label: 'Objetivo de relación',
                value: relationshipGoal.isNotEmpty ? relationshipGoal : null,
                items: const [
                  'Amistad',
                  'Citas',
                  'Relación seria',
                  'Casual',
                  'No estoy seguro'
                ],
                onChanged: onRelationshipGoalChanged,
                validatorMsg: 'Por favor selecciona tu objetivo de relación',
              ),
              const SizedBox(height: 16),
              _buildNumericField(
                label: 'Edad',
                initialValue: age,
                onChanged: onAgeChanged,
                validatorMsg: 'Por favor, ingresa tu edad',
                min: 18,
                max: 100,
              ),
              const SizedBox(height: 16),
              _buildNumericField(
                label: 'Altura (cm)',
                initialValue: height,
                onChanged: onHeightChanged,
                validatorMsg: 'Por favor, ingresa tu altura',
                min: 120,
                max: 250,
              ),
              const SizedBox(height: 16),
              _buildNumericField(
                label: 'Peso (kg)',
                initialValue: weight,
                onChanged: onWeightChanged,
                validatorMsg: 'Por favor, ingresa tu peso',
                min: 30,
                max: 250,
              ),
              const SizedBox(height: 16),
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
