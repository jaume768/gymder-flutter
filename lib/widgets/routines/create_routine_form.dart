import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/routine.dart';
import '../../providers/auth_provider.dart';
import '../../services/routine_service.dart';

class CreateRoutineForm extends StatefulWidget {
  final Function onRoutineCreated;
  final Routine? routineToEdit;

  const CreateRoutineForm({
    Key? key,
    required this.onRoutineCreated,
    this.routineToEdit,
  }) : super(key: key);

  @override
  _CreateRoutineFormState createState() => _CreateRoutineFormState();
}

class _CreateRoutineFormState extends State<CreateRoutineForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final List<Map<String, dynamic>> _exercises = [];
  bool _isLoading = false;
  String _errorMessage = '';

  // Controladores temporales para agregar un nuevo ejercicio
  final _exerciseNameController = TextEditingController();
  final _seriesController = TextEditingController();
  final _repsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Si estamos editando una rutina existente, cargamos sus datos
    if (widget.routineToEdit != null) {
      _nameController.text = widget.routineToEdit!.name;
      
      // Convertimos los ejercicios existentes al formato interno
      for (var exercise in widget.routineToEdit!.exercises) {
        _exercises.add({
          'name': exercise.name,
          'series': exercise.series,
          'repetitions': exercise.repetitions,
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _exerciseNameController.dispose();
    _seriesController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _addExercise() {
    // Validar los campos del ejercicio
    if (_exerciseNameController.text.isEmpty || 
        _seriesController.text.isEmpty || 
        _repsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('fill_all_exercise_fields'))),
      );
      return;
    }

    try {
      final series = int.parse(_seriesController.text);
      final reps = int.parse(_repsController.text);

      if (series <= 0 || reps <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('series_reps_must_be_positive'))),
        );
        return;
      }

      setState(() {
        _exercises.add({
          'name': _exerciseNameController.text,
          'series': series,
          'repetitions': reps,
        });

        // Limpiar los campos después de agregar
        _exerciseNameController.clear();
        _seriesController.clear();
        _repsController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('invalid_number_format'))),
      );
    }
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  Future<void> _saveRoutine() async {
    if (_formKey.currentState!.validate()) {
      if (_exercises.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('add_at_least_one_exercise'))),
        );
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final token = await auth.getToken();
        
        if (token == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = tr('token_not_found_login');
          });
          return;
        }

        final routineService = RoutineService(token: token);
        Map<String, dynamic> result;

        if (widget.routineToEdit != null) {
          // Actualizar rutina existente
          result = await routineService.updateRoutine(
            widget.routineToEdit!.id!,
            _nameController.text,
            _exercises,
          );
        } else {
          // Crear nueva rutina
          result = await routineService.createRoutine(
            _nameController.text,
            _exercises,
          );
        }

        if (result['success'] == true) {
          Navigator.pop(context);
          widget.onRoutineCreated();
        } else {
          setState(() {
            _errorMessage = result['message'] ?? tr('error_saving_routine');
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = '${tr('error')}: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculamos el porcentaje de la pantalla para que el modal no sea demasiado grande
    final height = MediaQuery.of(context).size.height * 0.85;
    
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra superior con título y botón de cerrar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.routineToEdit != null
                        ? tr('edit_routine')
                        : tr('create_routine'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Formulario scrolleable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre de la rutina
                      Text(
                        tr('routine_name'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: tr('enter_routine_name'),
                          hintStyle: TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.black45,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return tr('routine_name_required');
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Título de ejercicios
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr('exercises'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${_exercises.length} ${tr('added')}',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Lista de ejercicios agregados
                      ..._exercises.asMap().entries.map((entry) {
                        final index = entry.key;
                        final exercise = entry.value;
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          color: Colors.black38,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.white10),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            title: Text(
                              exercise['name'],
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${exercise['series']}x${exercise['repetitions']}',
                              style: TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red[300]),
                              onPressed: () => _removeExercise(index),
                            ),
                          ),
                        );
                      }).toList(),
                      
                      const SizedBox(height: 16),
                      
                      // Formulario para agregar nuevo ejercicio
                      Card(
                        color: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.white10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('add_exercise'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Nombre del ejercicio
                              TextFormField(
                                controller: _exerciseNameController,
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: tr('exercise_name'),
                                  hintStyle: TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor: Colors.black45,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Series y repeticiones en la misma fila
                              Row(
                                children: [
                                  // Series
                                  Expanded(
                                    child: TextFormField(
                                      controller: _seriesController,
                                      style: TextStyle(color: Colors.white),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: InputDecoration(
                                        hintText: tr('series'),
                                        hintStyle: TextStyle(color: Colors.white54),
                                        filled: true,
                                        fillColor: Colors.black45,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 8),
                                  
                                  // Repeticiones
                                  Expanded(
                                    child: TextFormField(
                                      controller: _repsController,
                                      style: TextStyle(color: Colors.white),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: InputDecoration(
                                        hintText: tr('repetitions'),
                                        hintStyle: TextStyle(color: Colors.white54),
                                        filled: true,
                                        fillColor: Colors.black45,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Botón para agregar ejercicio
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _addExercise,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    tr('add'),
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _errorMessage,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Botón de guardar en la parte inferior
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white24),
                ),
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveRoutine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  disabledBackgroundColor: Colors.white54,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : Text(
                        tr('save'),
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
