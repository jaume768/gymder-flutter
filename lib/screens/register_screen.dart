import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // <-- Para seleccionar fotos
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final bool fromGoogle;

  const RegisterScreen({Key? key, this.fromGoogle = false}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late PageController _pageController;

  int _currentStep = 0;
  // Seguimos con 9 pasos (0 a 8)
  final int _totalSteps = 9;

  String email = '';
  String password = '';
  String username = '';

  /// -- NUEVO: variables para nombre y apellido
  String firstName = '';
  String lastName = '';

  DateTime? birthDate;
  String gender = '';
  List<String> seeking = [];
  String relationshipGoal = '';
  String location = '';
  String gymStage = '';

  /// -- NUEVO: variables para altura y peso
  double? height;
  double? weight;

  final List<File> selectedPhotos = [];

  String errorMessage = '';
  bool isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.fromGoogle) {
      _currentStep = 1;
      _pageController = PageController(initialPage: 1);
    } else {
      _pageController = PageController();
    }
  }

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles != null) {
      if (selectedPhotos.length + pickedFiles.length > 5) {
        setState(() {
          errorMessage = 'Máximo 5 fotos en total';
        });
        return;
      }
      setState(() {
        errorMessage = '';
        selectedPhotos.addAll(pickedFiles.map((x) => File(x.path)));
      });
    }
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < _totalSteps - 1) {
        setState(() {
          errorMessage = '';
          _currentStep++;
        });
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _previousStep() {
    // Evitar retroceso de paso 1 a 0 si viene de Google
    if (widget.fromGoogle && _currentStep == 1) return;

    if (_currentStep > 0) {
      setState(() {
        errorMessage = '';
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (email.isEmpty || password.isEmpty) {
          setState(() {
            errorMessage = 'Completa tu correo y contraseña';
          });
          return false;
        }
        break;
      case 1:
        if (username.isEmpty || firstName.isEmpty || lastName.isEmpty) {
          setState(() {
            errorMessage = 'Ingresa tu username, nombre y apellido';
          });
          return false;
        }
        break;
      case 2:
        if (birthDate == null) {
          setState(() {
            errorMessage = 'Selecciona tu fecha de nacimiento';
          });
          return false;
        }
        break;
      case 3:
        if (gender.isEmpty) {
          setState(() {
            errorMessage = 'Selecciona tu género';
          });
          return false;
        }
        break;
      case 4:
        if (seeking.isEmpty) {
          setState(() {
            errorMessage = 'Selecciona al menos una opción';
          });
          return false;
        }
        break;
      case 5:
        if (relationshipGoal.isEmpty) {
          setState(() {
            errorMessage = 'Selecciona tu objetivo de relación';
          });
          return false;
        }
        break;
      case 6:
        if (location.isEmpty) {
          setState(() {
            errorMessage = 'Ingresa tu ubicación actual';
          });
          return false;
        }
        break;
      case 7:
        // Validamos etapa, altura y peso
        if (gymStage.isEmpty || height == null || weight == null) {
          setState(() {
            errorMessage =
                'Selecciona tu etapa del gym, e ingresa altura y peso';
          });
          return false;
        }
        break;
      case 8:
        if (selectedPhotos.length < 2) {
          setState(() {
            errorMessage = 'Por favor, sube al menos 2 fotos';
          });
          return false;
        }
        break;
      default:
        return true;
    }
    return true;
  }

  Future<void> _submitRegister() async {
    if (!_validateCurrentStep()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    if (widget.fromGoogle) {
      final token = await authProvider.getToken();
      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'No se encontró token';
        });
        return;
      }
      final userService = UserService(token: token);
      final updateResult = await userService.updateProfile({
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'gender': gender,
        'seeking': seeking,
        'relationshipGoal': relationshipGoal,
        'height': height,
        'weight': weight,
        'goal': gymStage,
      });
      if (!(updateResult['success'] ?? false)) {
        setState(() {
          isLoading = false;
          errorMessage =
              updateResult['message'] ?? 'Error al actualizar el perfil';
        });
        return;
      }
      // Subir fotos
      final uploadResult = await userService.uploadPhotos(selectedPhotos);
      if (uploadResult['success'] == true) {
        await authProvider.refreshUser();
        setState(() {
          isLoading = false;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        setState(() {
          isLoading = false;
          errorMessage = uploadResult['message'] ?? 'Error al subir fotos';
        });
      }
    } else {
      print("Enviando => height: $height, weight: $weight, gymStage: $gymStage");
      // Flujo normal de registro
      final result = await authProvider.register(
        email: email,
        password: password,
        username: username,
        firstName: firstName,
        lastName: lastName,
        gender: gender,
        seeking: seeking,
        relationshipGoal: relationshipGoal,
        height: height,
        weight: weight,
        gymStage: gymStage,
      );

      if (result['success'] == true) {
        final token = result['token'];
        if (token != null) {
          final userService = UserService(token: token);
          final uploadResult = await userService.uploadPhotos(selectedPhotos);
          if (uploadResult['success'] == true) {
            setState(() {
              isLoading = false;
            });
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          } else {
            setState(() {
              isLoading = false;
              errorMessage = uploadResult['message'] ?? 'Error al subir fotos';
            });
          }
        } else {
          setState(() {
            isLoading = false;
            errorMessage = 'No se recibió token tras registrar';
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = result['message'] ?? 'Error al registrar';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (_currentStep + 1) / _totalSteps;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(64, 65, 65, 1),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de Progreso
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white54,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep0(),
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                  _buildStep5(),
                  _buildStep6(),
                  _buildStep7(), // <-- Paso modificado
                  _buildStep8(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: const Color.fromRGBO(64, 65, 65, 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (_currentStep > 0 && !(widget.fromGoogle && _currentStep == 1))
            ElevatedButton(
              onPressed: _previousStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          const Spacer(),
          if (_currentStep < _totalSteps - 1)
            ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
              ),
              child: const Icon(Icons.arrow_forward, color: Colors.black),
            )
          else
            ElevatedButton(
              onPressed: isLoading ? null : _submitRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
              ),
              child: isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    )
                  : const Text(
                      'Finalizar',
                      style: TextStyle(color: Colors.black),
                    ),
            ),
        ],
      ),
    );
  }

  // ========================
  // Steps (Screens)
  // ========================

  Widget _buildStep0() {
    return _buildStepTemplate(
      title: 'Bienvenido',
      subtitle: 'Ingresa tu correo electrónico y contraseña',
      child: Column(
        children: [
          const SizedBox(height: 20),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Correo Electrónico'),
            keyboardType: TextInputType.emailAddress,
            onChanged: (value) => email = value,
          ),
          const SizedBox(height: 20),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Contraseña'),
            obscureText: true,
            onChanged: (value) => password = value,
          ),
          if (errorMessage.isNotEmpty && _currentStep == 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(errorMessage,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
          const SizedBox(height: 20), // Espacio adicional
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '¿Ya tienes una cuenta?',
                style: TextStyle(color: Colors.white),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text(
                  'Inicia Sesión',
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return _buildStepTemplate(
      title: '¿Cómo te llamas?',
      subtitle: 'Introduce tu username, nombre y apellido',
      child: Column(
        children: [
          const SizedBox(height: 20),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Username'),
            onChanged: (value) => username = value,
          ),
          const SizedBox(height: 20),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Nombre'),
            onChanged: (value) => firstName = value,
          ),
          const SizedBox(height: 20),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Apellido'),
            onChanged: (value) => lastName = value,
          ),
          if (errorMessage.isNotEmpty && _currentStep == 1)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(errorMessage,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return _buildStepTemplate(
      title: '¿Cuándo es tu cumpleaños?',
      subtitle: 'Selecciona tu fecha de nacimiento',
      child: Column(
        children: [
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final now = DateTime.now();
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime(now.year - 18),
                firstDate: DateTime(1900),
                lastDate: now,
              );
              if (pickedDate != null) {
                setState(() {
                  birthDate = pickedDate;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
            ),
            child: Text(
              birthDate == null
                  ? 'Seleccionar fecha'
                  : 'Tu cumpleaños: ${birthDate!.day}/${birthDate!.month}/${birthDate!.year}',
              style: const TextStyle(color: Colors.black),
            ),
          ),
          if (errorMessage.isNotEmpty && _currentStep == 2)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(errorMessage,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    final genders = [
      'Masculino',
      'Femenino',
      'No Binario',
      'Prefiero no decirlo',
      'Otro',
    ];

    return _buildStepTemplate(
      title: '¿Qué género te representa mejor?',
      subtitle: 'Selecciona tu género',
      child: DropdownButtonFormField<String>(
        decoration: _dropdownDecoration('Género'),
        value: gender.isEmpty ? null : gender,
        style: const TextStyle(color: Colors.white),
        selectedItemBuilder: (context) {
          return genders.map((item) {
            return Text(item, style: const TextStyle(color: Colors.white));
          }).toList();
        },
        items: genders.map((g) {
          return DropdownMenuItem(
            value: g,
            child: Text(g, style: const TextStyle(color: Colors.black)),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            gender = value ?? '';
          });
        },
      ),
    );
  }

  Widget _buildStep4() {
    final seekingOptions = [
      'Masculino',
      'Femenino',
      'No Binario',
      'Prefiero no decirlo',
      'Otro'
    ];

    return _buildStepTemplate(
      title: '¿A quién quieres conocer?',
      subtitle: 'Selecciona uno o varios',
      child: Column(
        children: [
          const SizedBox(height: 16),
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: seekingOptions.map((option) {
              final isSelected = seeking.contains(option);
              return FilterChip(
                label:
                    Text(option, style: const TextStyle(color: Colors.black)),
                selected: isSelected,
                backgroundColor: Colors.white54,
                selectedColor: Colors.white,
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      seeking.add(option);
                    } else {
                      seeking.remove(option);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5() {
    final goals = ['Amistad', 'Relación', 'Casual', 'Otro'];

    return _buildStepTemplate(
      title: '¿Qué estás buscando?',
      subtitle: 'Selecciona un objetivo',
      child: DropdownButtonFormField<String>(
        decoration: _dropdownDecoration('Objetivo de relación'),
        style: const TextStyle(color: Colors.white),
        hint: const Text(
          'Seleccionar objetivo',
          style: TextStyle(color: Colors.white70),
        ),
        selectedItemBuilder: (context) {
          return goals.map((item) {
            return Text(item, style: const TextStyle(color: Colors.white));
          }).toList();
        },
        value: relationshipGoal.isEmpty ? null : relationshipGoal,
        items: goals.map((g) {
          return DropdownMenuItem(
            value: g,
            child: Text(g, style: const TextStyle(color: Colors.black)),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            relationshipGoal = value ?? '';
          });
        },
      ),
    );
  }

  Widget _buildStep6() {
    return _buildStepTemplate(
      title: '¿Dónde te encuentras?',
      subtitle: 'Comparte tu ubicación actual',
      child: TextFormField(
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration('Ej: Ciudad, País'),
        onChanged: (value) => location = value,
      ),
    );
  }

  /// Paso 7 modificado para pedir etapa, altura y peso
  Widget _buildStep7() {
    final gymStages = ['Volumen', 'Definición', 'Mantenimiento'];

    return _buildStepTemplate(
      title: 'Tu etapa del gym, altura y peso',
      subtitle: 'Selecciona tu objetivo actual, e ingresa altura y peso',
      child: Column(
        children: [
          // Etapa del gym
          DropdownButtonFormField<String>(
            decoration: _dropdownDecoration('Etapa'),
            style: const TextStyle(color: Colors.white),
            selectedItemBuilder: (context) {
              return gymStages.map((stage) {
                return Text(stage, style: const TextStyle(color: Colors.white));
              }).toList();
            },
            value: gymStage.isEmpty ? null : gymStage,
            items: gymStages.map((stage) {
              return DropdownMenuItem(
                value: stage,
                child: Text(stage, style: const TextStyle(color: Colors.black)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                gymStage = value ?? '';
              });
            },
          ),
          const SizedBox(height: 20),

          // Altura
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Altura (cm)'),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                height = double.tryParse(value);
              });
            },
          ),
          const SizedBox(height: 20),

          // Peso
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Peso (kg)'),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                weight = double.tryParse(value);
              });
            },
          ),

          if (errorMessage.isNotEmpty && _currentStep == 7)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(errorMessage,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
    );
  }

  Widget _buildStep8() {
    return _buildStepTemplate(
      title: 'Agrega tus fotos',
      subtitle: 'Necesitas al menos 2 fotos (máximo 5)',
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'Has seleccionado: ${selectedPhotos.length} foto(s)',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _pickImages,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child: const Text(
              'Seleccionar fotos',
              style: TextStyle(color: Colors.black),
            ),
          ),
          const SizedBox(height: 20),
          if (selectedPhotos.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: selectedPhotos.length,
                itemBuilder: (context, index) {
                  final file = selectedPhotos[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Image.file(
                      file,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          if (errorMessage.isNotEmpty && _currentStep == 8)
            Text(errorMessage, style: const TextStyle(color: Colors.redAccent)),
        ],
      ),
    );
  }

  // ====================================================
  // Plantillas de estilo
  // ====================================================

  Widget _buildStepTemplate({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
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
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white),
      hintStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white54),
        borderRadius: BorderRadius.circular(12.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white),
        borderRadius: BorderRadius.circular(12.0),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }
}
