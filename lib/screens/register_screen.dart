import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RegisterScreen extends StatefulWidget {
  final bool fromGoogle;

  const RegisterScreen({Key? key, this.fromGoogle = false}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late PageController _pageController;

  int _currentStep = 0;
  final int _totalSteps = 11;
  String verificationCode = '';
  final int emailVerificationStepIndex = 1;

  bool isCheckingUsername = false;
  bool _emailVerified = false;
  String usernameCheckMessage = '';

  String email = '';
  String password = '';
  String username = '';

  /// -- NUEVO: variables para nombre y apellido
  String firstName = '';
  String lastName = '';

  DateTime? birthDate;
  String gender = '';
  bool isLoadingLocation = false;
  List<String> seeking = [];
  String relationshipGoal = '';
  String location = '';
  String gymStage = '';
  double userLatitude = 0.0;
  double userLongitude = 0.0;

  /// -- NUEVO: variables para altura y peso
  double? height;
  double? weight;

  final List<File> selectedPhotos = [];

  String errorMessage = '';
  bool isLoading = false;

  File? profilePictureFile;
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

  Future<void> _checkUsernameAvailability(String username) async {
    setState(() {
      isCheckingUsername = true;
      usernameCheckMessage = 'Comprobando disponibilidad...';
    });

    final url = Uri.parse(
        'https://gymder-api-production.up.railway.app/api/users/check_username/$username');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        bool available = data['available'] ?? false;
        setState(() {
          isCheckingUsername = false;
          usernameCheckMessage =
              available ? 'Username disponible' : 'Username no disponible';
        });
      } else {
        setState(() {
          isCheckingUsername = false;
          usernameCheckMessage = 'Error al comprobar disponibilidad';
        });
      }
    } catch (e) {
      setState(() {
        isCheckingUsername = false;
        usernameCheckMessage = 'Error de conexión';
      });
    }
  }

  Future<bool> _checkEmailAvailability(String email) async {
    final url = Uri.parse(
        'https://gymder-api-production.up.railway.app/api/users/check_email/$email');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        bool available = data['available'] ?? false;
        return available;
      }
    } catch (e) {
      print('Error comprobando email: $e');
    }
    return false;
  }

  double? parseHeight(String input) {
    input = input.replaceAll("'", ".").replaceAll(",", ".");

    double? value = double.tryParse(input);
    if (value == null) {
      return null;
    }

    if (value < 3) {
      return value * 100;
    }

    return value;
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

  Future<void> _nextStep() async {
    if (_currentStep == 7 && location.isEmpty) {
      bool? continuar = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
                title: const Text("¿Sin ubicación?"),
                content: const Text(
                    "Si no proporcionas tu ubicación, se te mostrarán usuarios de manera aleatoria. "
                    "Podrás cambiar esto más tarde en tu perfil. ¿Deseas continuar sin ubicación?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancelar"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Continuar"),
                  ),
                ],
              ));

      if (continuar == false) {
        return;
      }
    }
    if (_validateCurrentStep()) {
      if (_currentStep == 0) {
        if (email.isEmpty || password.isEmpty) {
          setState(() {
            errorMessage = 'Completa tu correo y contraseña';
          });
          return;
        }
        setState(() {
          errorMessage = 'Comprobando disponibilidad de email...';
        });
        bool emailAvailable = await _checkEmailAvailability(email);
        if (!emailAvailable) {
          setState(() {
            errorMessage = 'El correo ya está en uso';
          });
          return;
        }
        await _sendVerificationEmail();
      }

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
        if (password.length < 6) {
          setState(() {
            errorMessage = 'La contraseña debe tener al menos 6 carácteres';
          });
          return false;
        }
        break;
      case 1: // Paso de verificación de email
        if (!_emailVerified) {
          setState(() {
            errorMessage = 'Debes verificar el código correctamente';
          });
          return false;
        }
        break;
      case 2: // Username, nombre y apellido
        if (username.isEmpty || firstName.isEmpty || lastName.isEmpty) {
          setState(() {
            errorMessage = 'Ingresa tu username, nombre y apellido';
          });
          return false;
        }
        RegExp digitRegex = RegExp(r'\d');
        if (digitRegex.hasMatch(firstName) || digitRegex.hasMatch(lastName)) {
          setState(() {
            errorMessage = 'El nombre y apellido no deben contener números';
          });
          return false;
        }
        if (usernameCheckMessage == 'Username no disponible') {
          setState(() {
            errorMessage = 'El username no está disponible';
          });
          return false;
        }
        break;
      case 3: // Fecha de nacimiento
        if (birthDate == null) {
          setState(() {
            errorMessage = 'Selecciona tu fecha de nacimiento';
          });
          return false;
        }
        final today = DateTime.now();
        int age = today.year - birthDate!.year;
        if (today.month < birthDate!.month ||
            (today.month == birthDate!.month && today.day < birthDate!.day)) {
          age--;
        }
        if (age < 18) {
          setState(() {
            errorMessage = 'Debes ser mayor de 18 años para continuar';
          });
          return false;
        }
        break;
      case 4: // Género
        if (gender.isEmpty) {
          setState(() {
            errorMessage = 'Selecciona tu género';
          });
          return false;
        }
        break;
      case 5: // Opciones de búsqueda (seeking)
        if (seeking.isEmpty) {
          setState(() {
            errorMessage = 'Selecciona al menos una opción';
          });
          return false;
        }
        break;
      case 6: // Propósito de conexión
        if (relationshipGoal.isEmpty) {
          setState(() {
            errorMessage = 'Selecciona tu propósito de conexión';
          });
          return false;
        }
        break;
      case 7:
        break;
      case 8: // Etapa del gym, altura y peso
        if (gymStage.isEmpty || height == null || weight == null) {
          setState(() {
            errorMessage =
                'Selecciona tu etapa del gym, e ingresa altura y peso';
          });
          return false;
        }
        break;
      case 9: // Foto de perfil (opcional)
        return true;
      case 10: // Fotos adicionales
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

  Future<void> _verifyEmailCode() async {
    final url = Uri.parse(
        'https://gymder-api-production.up.railway.app/api/users/verify-email');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': verificationCode}),
      );
      if (response.statusCode == 200) {
        setState(() {
          errorMessage = '';
          _emailVerified = true; // Marcar como verificado
          _currentStep = emailVerificationStepIndex + 1;
        });
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        setState(() {
          errorMessage = 'Código incorrecto';
          _emailVerified = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error de conexión: $e';
        _emailVerified = false;
      });
    }
  }

  Widget _buildStepEmailVerification() {
    return _buildStepTemplate(
      title: 'Verifica tu correo',
      subtitle: 'Ingresa el código que te enviamos a tu correo',
      child: Column(
        children: [
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Código de verificación'),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              verificationCode = value;
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _verifyEmailCode,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child:
                const Text('Verificar', style: TextStyle(color: Colors.black)),
          ),
          if (errorMessage.isNotEmpty &&
              _currentStep == emailVerificationStepIndex)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(errorMessage,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
    );
  }

  Future<void> _sendVerificationEmail() async {
    final url = Uri.parse(
        'https://gymder-api-production.up.railway.app/api/users/send-verification-email');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200) {
        print("Código de verificación enviado");
      } else {
        setState(() {
          errorMessage =
              'Error al enviar correo de verificación: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error de conexión al enviar el correo: $e';
      });
    }
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
        'latitude': userLatitude,
        'longitude': userLongitude,
      });
      if (!(updateResult['success'] ?? false)) {
        setState(() {
          isLoading = false;
          errorMessage =
              updateResult['message'] ?? 'Error al actualizar el perfil';
        });
        return;
      }
      if (profilePictureFile != null) {
        final userService = UserService(token: token);
        final profileResult =
            await userService.uploadProfilePicture(profilePictureFile!);
        if (profileResult['success'] != true) {
          setState(() {
            isLoading = false;
            errorMessage =
                profileResult['message'] ?? 'Error al subir foto de perfil';
          });
          return;
        }
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
      print(
          "Enviando => height: $height, weight: $weight, gymStage: $gymStage");
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
        latitude: location.isEmpty ? null : userLatitude,
        longitude: location.isEmpty ? null : userLongitude,
      );

      if (result['success'] == true) {
        final token = result['token'];
        if (token != null) {
          final userService = UserService(token: token);
          if (profilePictureFile != null) {
            final profileResult =
                await userService.uploadProfilePicture(profilePictureFile!);
            if (profileResult['success'] != true) {
              setState(() {
                isLoading = false;
                errorMessage =
                    profileResult['message'] ?? 'Error al subir foto de perfil';
              });
              return;
            }
          }
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
      backgroundColor: const Color.fromRGBO(34, 34, 34, 0.0),
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
                  _buildStepEmailVerification(),
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                  _buildStep5(),
                  _buildStep6(),
                  _buildStep7(),
                  _buildStepProfilePicture(),
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
      color: const Color.fromRGBO(20, 20, 20, 0.0),
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
            onChanged: (value) {
              setState(() {
                username = value;
              });
              if (value.isNotEmpty) {
                if (value.length < 4) {
                  setState(() {
                    isCheckingUsername = false;
                    usernameCheckMessage = 'Username no disponible';
                  });
                } else {
                  _checkUsernameAvailability(value);
                }
              } else {
                setState(() {
                  usernameCheckMessage = '';
                });
              }
            },
          ),
          if (usernameCheckMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                usernameCheckMessage,
                style: TextStyle(
                  color: usernameCheckMessage == 'Username disponible'
                      ? Colors.green
                      : Colors.redAccent,
                ),
              ),
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
            child: Text(g, style: const TextStyle(color: Colors.white)),
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
                label: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                ),
                selected: isSelected,
                backgroundColor: Colors.grey[900],
                selectedColor: Colors.blueAccent,
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
      subtitle: 'Propósito de conexión',
      child: DropdownButtonFormField<String>(
        decoration: _dropdownDecoration('Propósito de conexión'),
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
            child: Text(g, style: const TextStyle(color: Colors.white)),
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
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: isLoadingLocation ? null : _obtenerUbicacion,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            icon: Icon(
              Icons.my_location,
              color: Colors.black,
            ),
            label: Text(
              location.isEmpty ? 'Obtener mi ubicación' : 'Ubicación detectada',
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
          const SizedBox(height: 20),
          if (isLoadingLocation)
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          if (location.isNotEmpty)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Card(
                key: ValueKey<String>(location),
                color: Colors.white24,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                elevation: 4,
                child: ListTile(
                  leading: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 30,
                  ),
                  title: Text(
                    location,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                    ),
                    onPressed: _obtenerUbicacion,
                  ),
                ),
              ),
            ),
          if (errorMessage.isNotEmpty && _currentStep == 6)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _obtenerUbicacion() async {
    setState(() {
      isLoadingLocation = true;
      errorMessage = '';
    });

    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          errorMessage =
              'Permiso de ubicación denegado. No se puede continuar.';
          isLoadingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        String ciudad = placemark.locality ?? '';
        String pais = placemark.country ?? '';

        setState(() {
          location = '$ciudad, $pais';
          userLatitude = position.latitude;
          userLongitude = position.longitude;
          isLoadingLocation = false;
        });
      } else {
        setState(() {
          errorMessage = 'No se pudo determinar la ciudad.';
          isLoadingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error al obtener la ubicación: $e';
        isLoadingLocation = false;
      });
    }
  }

  Widget _buildStep7() {
    final gymStages = ['Volumen', 'Definición', 'Mantenimiento'];

    return _buildStepTemplate(
      title: 'Tu etapa del gym, altura y peso',
      subtitle: 'Selecciona tu objetivo actual, e ingresa altura y peso',
      child: Column(
        children: [
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
                child: Text(stage, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                gymStage = value ?? '';
              });
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Altura (cm)'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              setState(() {
                height = parseHeight(value);
              });
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Peso (kg)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
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

  Widget _buildStepProfilePicture() {
    return _buildStepTemplate(
      title: 'Foto de perfil',
      subtitle: 'Selecciona una foto de perfil',
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 75,
            backgroundImage: profilePictureFile != null
                ? FileImage(profilePictureFile!)
                : const AssetImage('assets/images/default_profile.png'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final pickedFile =
                  await _picker.pickImage(source: ImageSource.gallery);
              if (pickedFile != null) {
                setState(() {
                  profilePictureFile = File(pickedFile.path);
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child: const Text(
              'Cambiar foto',
              style: TextStyle(color: Colors.black),
            ),
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
                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Image.file(
                          file,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedPhotos.removeAt(index);
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      )
                    ],
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
