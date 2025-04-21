import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import '../utils/error_handler.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'package:http/http.dart' as http;
import 'terms_conditions_screen.dart';
import 'privacy_policy_screen.dart';

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
  final RegExp emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");

  bool isCheckingUsername = false;
  bool _emailVerified = false;
  String usernameCheckMessage = '';

  String email = '';
  String password = '';
  String username = '';

  // NUEVO: variables para nombre y apellido
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

  // NUEVO: variables para altura y peso
  double? height;
  double? weight;
  
  // Variable para aceptación de términos y condiciones
  bool acceptedTerms = false;

  final List<File> selectedPhotos = [];

  String errorMessage = '';
  bool isLoading = false;

  // Mapa para errores específicos de campos
  Map<String, String> fieldErrors = {};

  File? profilePictureFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.fromGoogle) {
      _currentStep = 2;
      _pageController = PageController(initialPage: 2);
    } else {
      _pageController = PageController();
    }
  }

  // Método para obtener error específico de un campo
  String? getFieldError(String fieldName) {
    return fieldErrors[fieldName];
  }

  // Método para limpiar todos los errores
  void clearErrors() {
    setState(() {
      errorMessage = '';
      fieldErrors = {};
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.isEmpty) {
      setState(() {
        isCheckingUsername = false;
        usernameCheckMessage = '';
      });
      return;
    }

    setState(() {
      isCheckingUsername = true;
      usernameCheckMessage = tr("checking_availability");
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
          if (available) {
            usernameCheckMessage = tr("username_available");
            fieldErrors.remove('username');
          } else {
            usernameCheckMessage = tr("username_unavailable");
            fieldErrors['username'] = tr("username_unavailable");
          }
        });
      } else {
        setState(() {
          isCheckingUsername = false;
          usernameCheckMessage = tr("error_checking_availability");
        });
      }
    } catch (e) {
      setState(() {
        isCheckingUsername = false;
        usernameCheckMessage = tr("connection_error");
      });
    }
  }

  Future<bool> _checkEmailAvailability(String email) async {
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      return false;
    }

    setState(() {
      errorMessage = tr("checking_email_availability");
    });

    final url = Uri.parse(
        'https://gymder-api-production.up.railway.app/api/users/check_email/$email');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        bool available = data['available'] ?? false;

        if (!available) {
          setState(() {
            fieldErrors['email'] = tr("email_in_use");
          });
        } else {
          setState(() {
            fieldErrors.remove('email');
          });
        }

        return available;
      }
    } catch (e) {
      setState(() {
        errorMessage = '${tr("error_checking_email")} $e';
      });
    }
    return false;
  }

  Future<void> _nextStep() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearFieldErrors();

    // Actualizar fieldErrors con los del provider para mantener consistencia
    fieldErrors = Map.from(authProvider.fieldErrors);

    if (_currentStep == 7 && location.isEmpty) {
      bool? continuar = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
                title: Text(tr("no_location")),
                content: Text(tr("no_location_dialog_content")),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(tr("cancel")),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(tr("continue")),
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
            errorMessage = tr("fill_email_password");
            if (email.isEmpty) fieldErrors['email'] = tr("email_required");
            if (password.isEmpty)
              fieldErrors['password'] = tr("password_required");
          });
          return;
        }

        bool emailAvailable = await _checkEmailAvailability(email);
        if (!emailAvailable) {
          setState(() {
            errorMessage = fieldErrors['email'] ?? tr("email_in_use");
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

  bool _validateCurrentStep() {
    // Limpiar errores antes de validar
    setState(() {
      errorMessage = '';
      fieldErrors.clear();
    });

    switch (_currentStep) {
      case 0:
        if (email.isEmpty || password.isEmpty) {
          setState(() {
            errorMessage = tr("fill_email_password");
            if (email.isEmpty) fieldErrors['email'] = tr("email_required");
            if (password.isEmpty)
              fieldErrors['password'] = tr("password_required");
          });
          return false;
        }
        if (!acceptedTerms) {
          setState(() {
            errorMessage = tr("must_accept_terms");
            fieldErrors['terms'] = tr("must_accept_terms");
          });
          return false;
        }
        if (!emailRegex.hasMatch(email)) {
          setState(() {
            errorMessage = tr("enter_email_password");
            fieldErrors['email'] = tr("invalid_email_format");
          });
          return false;
        }
        if (password.length < 6) {
          setState(() {
            errorMessage = tr("password_min_length");
            fieldErrors['password'] = tr("password_min_length");
          });
          return false;
        }
        break;
      case 1:
        if (!_emailVerified) {
          setState(() {
            errorMessage = tr("verify_code_error");
            fieldErrors['verificationCode'] = tr("verify_code_error");
          });
          return false;
        }
        break;
      case 2:
        if (username.isEmpty || firstName.isEmpty || lastName.isEmpty) {
          setState(() {
            errorMessage = tr("enter_username_first_last");
            if (username.isEmpty)
              fieldErrors['username'] = tr("username_required");
            if (firstName.isEmpty)
              fieldErrors['firstName'] = tr("first_name_required");
            if (lastName.isEmpty)
              fieldErrors['lastName'] = tr("last_name_required");
          });
          return false;
        }
        RegExp digitRegex = RegExp(r'\d');
        if (digitRegex.hasMatch(firstName) || digitRegex.hasMatch(lastName)) {
          setState(() {
            errorMessage = tr("name_no_numbers");
            if (digitRegex.hasMatch(firstName))
              fieldErrors['firstName'] = tr("name_no_numbers");
            if (digitRegex.hasMatch(lastName))
              fieldErrors['lastName'] = tr("name_no_numbers");
          });
          return false;
        }
        if (usernameCheckMessage == tr("username_unavailable")) {
          setState(() {
            errorMessage = tr("username_not_available");
            fieldErrors['username'] = tr("username_not_available");
          });
          return false;
        }
        break;
      case 3:
        if (birthDate == null) {
          setState(() {
            errorMessage = tr("select_your_birthdate");
            fieldErrors['birthDate'] = tr("select_your_birthdate");
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
            errorMessage = tr("must_be_18");
            fieldErrors['birthDate'] = tr("must_be_18");
          });
          return false;
        }
        break;
      case 4:
        if (gender.isEmpty) {
          setState(() {
            errorMessage = tr("select_gender");
            fieldErrors['gender'] = tr("select_gender");
          });
          return false;
        }
        break;
      case 5:
        if (seeking.isEmpty) {
          setState(() {
            errorMessage = tr("select_one_or_more");
            fieldErrors['seeking'] = tr("select_one_or_more");
          });
          return false;
        }
        break;
      case 6:
        if (relationshipGoal.isEmpty) {
          setState(() {
            errorMessage = tr("select_connection_purpose");
            fieldErrors['relationshipGoal'] = tr("select_connection_purpose");
          });
          return false;
        }
        break;
      case 7:
        break;
      case 8:
        if (gymStage.isEmpty || height == null || weight == null) {
          setState(() {
            errorMessage = tr("select_your_gym_stage_height_weight");
            if (gymStage.isEmpty)
              fieldErrors['gymStage'] = tr("gym_stage_required");
            if (height == null) fieldErrors['height'] = tr("height_required");
            if (weight == null) fieldErrors['weight'] = tr("weight_required");
          });
          return false;
        }

        // Validar que la altura esté entre 100 y 250 cm
        if (height! < 100 || height! > 250) {
          setState(() {
            errorMessage = tr("height_out_of_range");
            fieldErrors['height'] = tr("height_must_be_between_100_250");
          });
          return false;
        }

        // Validar que el peso esté entre 40 y 200 kg
        if (weight! < 40 || weight! > 200) {
          setState(() {
            errorMessage = tr("weight_out_of_range");
            fieldErrors['weight'] = tr("weight_must_be_between_40_200");
          });
          return false;
        }
        break;
      case 9:
        return true;
      case 10:
        if (selectedPhotos.length < 2) {
          setState(() {
            errorMessage = tr("upload_minimum_photos");
            fieldErrors['photos'] = tr("upload_minimum_photos");
          });
          return false;
        }
        // Validación de términos y condiciones movida al paso 0
        break;
      default:
        return true;
    }
    return true;
  }

  Future<void> _verifyEmailCode() async {
    if (verificationCode.isEmpty) {
      setState(() {
        errorMessage = tr("verification_code_required");
        fieldErrors['verificationCode'] = tr("verification_code_required");
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
      fieldErrors.remove('verificationCode');
    });

    final url = Uri.parse(
        'https://gymder-api-production.up.railway.app/api/users/verify-email');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': verificationCode}),
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200) {
        setState(() {
          errorMessage = '';
          _emailVerified = true;
          _currentStep = emailVerificationStepIndex + 1;
        });
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          errorMessage = data['message'] ?? tr("invalid_code");
          fieldErrors['verificationCode'] = errorMessage;
          _emailVerified = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = tr("connection_error") + ": $e";
        fieldErrors['verificationCode'] = errorMessage;
        _emailVerified = false;
      });
    }
  }

  Future<void> _sendVerificationEmail() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final url = Uri.parse(
        'https://gymder-api-production.up.railway.app/api/users/send-verification-email');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200) {
        print("Código de verificación enviado");
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr("verification_code_sent")),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          errorMessage =
              data['message'] ?? tr("error_sending_verification_email");
          fieldErrors['email'] = errorMessage;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = tr("connection_error_sending_email") + ": $e";
      });
    }
  }

  Future<void> _submitRegister() async {
    if (!_validateCurrentStep()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      isLoading = true;
      errorMessage = '';
      fieldErrors.clear();
    });

    try {
      // Validar imágenes primero, independientemente de si es registro desde Google o normal
      if (selectedPhotos.isNotEmpty) {
        // Usar UserService sin token para validar imágenes (no requiere autenticación)
        final userService = UserService(token: '');
        final validationResult =
            await userService.validateImages(selectedPhotos);

        if (validationResult['success'] != true) {
          setState(() {
            isLoading = false;
            errorMessage =
                validationResult['message'] ?? tr("explicit_content_detected");
            fieldErrors['photos'] = tr("explicit_content_detected");
          });

          // Mostrar diálogo con error de imágenes explícitas
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(tr("image_validation_error"),
                  style: const TextStyle(color: Colors.red)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(errorMessage),
                    const SizedBox(height: 16),
                    Text(tr("cannot_proceed_with_explicit")),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr("ok")),
                ),
              ],
            ),
          );
          return;
        }
      }

      // Continuar con el registro normal o actualización desde Google
      if (widget.fromGoogle) {
        final token = await authProvider.getToken();
        if (token == null) {
          setState(() {
            isLoading = false;
            errorMessage = tr("token_not_found");
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
                updateResult['message'] ?? tr("error_updating_profile");

            // Procesar errores específicos de campo si existen
            if (updateResult.containsKey('fieldErrors')) {
              updateResult['fieldErrors'].forEach((key, value) {
                fieldErrors[key] = value.toString();
              });
            }
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
              errorMessage = profileResult['message'] ??
                  tr("error_uploading_profile_picture");
            });
            return;
          }
        }

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
            errorMessage =
                uploadResult['message'] ?? tr("error_uploading_photos");
          });
        }
      } else {
        print(
            "Enviando => height: $height, weight: $weight, gymStage: $gymStage");
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

        // Actualizar field errors desde el provider
        setState(() {
          fieldErrors = Map.from(authProvider.fieldErrors);
        });

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
                  errorMessage = profileResult['message'] ??
                      tr("error_uploading_profile_picture");
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
                errorMessage =
                    uploadResult['message'] ?? tr("error_uploading_photos");
              });
            }
          } else {
            setState(() {
              isLoading = false;
              errorMessage = tr("no_token_received_after_register");
            });
          }
        } else {
          setState(() {
            isLoading = false;
            errorMessage = result['message'] ?? tr("error_register");

            // Si hay errores de campo específicos, actualizarlos desde el resultado
            if (result.containsKey('fieldErrors')) {
              result['fieldErrors'].forEach((key, value) {
                fieldErrors[key] = value.toString();
              });
            }
          });

          // Mostrar diálogo de error con los detalles específicos
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(tr("registration_error"),
                  style: const TextStyle(color: Colors.red)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(errorMessage),
                    if (fieldErrors.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(tr("field_specific_errors"),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...fieldErrors.entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                                "• ${_getFieldDisplayName(entry.key)}: ${entry.value}"),
                          )),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr("ok")),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = tr("unexpected_error") + ": $e";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Función auxiliar para mostrar nombres de campo más legibles
  String _getFieldDisplayName(String fieldName) {
    switch (fieldName) {
      case 'email':
        return tr("email");
      case 'password':
        return tr("password");
      case 'username':
        return tr("username");
      case 'firstName':
        return tr("first_name");
      case 'lastName':
        return tr("last_name");
      case 'birthDate':
        return tr("birth_date");
      case 'gender':
        return tr("gender");
      case 'seeking':
        return tr("looking_for");
      case 'relationshipGoal':
        return tr("relationship_goal");
      case 'gymStage':
        return tr("gym_stage");
      case 'height':
        return tr("height");
      case 'weight':
        return tr("weight");
      case 'photos':
        return tr("photos");
      case 'verificationCode':
        return tr("verification_code");
      default:
        return fieldName;
    }
  }

  // Actualizar método para decorar InputField con errores
  InputDecoration _inputDecoration(String label, {String? fieldName}) {
    final hasError = fieldName != null && fieldErrors.containsKey(fieldName);
    final errorText = hasError ? fieldErrors[fieldName] : null;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: hasError ? Colors.redAccent : Colors.white),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: hasError ? Colors.redAccent : Colors.white54,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: hasError ? Colors.redAccent : Colors.white,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      errorText: errorText,
      errorStyle: const TextStyle(color: Colors.redAccent),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  // También actualizamos el dropdown decoration
  InputDecoration _dropdownDecoration(String label, {String? fieldName}) {
    final hasError = fieldName != null && fieldErrors.containsKey(fieldName);
    final errorText = hasError ? fieldErrors[fieldName] : null;

    return InputDecoration(
      labelText: label,
      labelStyle:
          TextStyle(color: hasError ? Colors.redAccent : Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: hasError ? Colors.redAccent : Colors.white54,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: hasError ? Colors.redAccent : Colors.white,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      errorText: errorText,
      errorStyle: const TextStyle(color: Colors.redAccent),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  void _previousStep() {
    // Evitar retroceso de paso 1 a 0 si viene de Google
    if (widget.fromGoogle && _currentStep == 1) return;

    if (_currentStep > 0) {
      setState(() {
        errorMessage = '';
        fieldErrors.clear();
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
          errorMessage = tr("max_photos_error");
          fieldErrors['photos'] = tr("max_photos_error");
        });
        return;
      }
      setState(() {
        errorMessage = '';
        fieldErrors.remove('photos');
        selectedPhotos.addAll(pickedFiles.map((x) => File(x.path)));
      });
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
                  : Text(
                      tr("finalize"),
                      style: const TextStyle(color: Colors.black),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep0() {
    return _buildStepTemplate(
      title: tr("welcome"),
      subtitle: tr("enter_email_password"),
      child: Column(
        children: [
          const SizedBox(height: 20),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration:
                _inputDecoration(tr("email_only"), fieldName: 'email'),
            keyboardType: TextInputType.emailAddress,
            onChanged: (value) => email = value,
            onEditingComplete: () {
              if (email.isNotEmpty && !emailRegex.hasMatch(email)) {
                setState(() {
                  fieldErrors['email'] = tr("invalid_email_format");
                });
              } else if (email.isNotEmpty) {
                setState(() {
                  fieldErrors.remove('email');
                });
                _checkEmailAvailability(email);
              }
              FocusScope.of(context).nextFocus();
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(tr("password"), fieldName: 'password'),
            obscureText: true,
            onChanged: (value) => password = value,
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Checkbox(
                value: acceptedTerms,
                onChanged: (value) {
                  setState(() {
                    acceptedTerms = value ?? false;
                    if (acceptedTerms) {
                      fieldErrors.remove('terms');
                    }
                  });
                },
                fillColor: MaterialStateProperty.resolveWith<Color>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.blueAccent;
                    }
                    return Colors.grey;
                  },
                ),
              ),
              Expanded(
                child: Wrap(
                  children: [
                    Text(
                      tr("accept_terms"),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TermsConditionsScreen(),
                          ),
                        );
                      },
                      child: Text(
                        tr("terms_conditions"),
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tr("and"),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                      child: Text(
                        tr("privacy_policy"),
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (fieldErrors.containsKey('terms'))
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 40),
              child: Text(
                fieldErrors['terms']!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          if (errorMessage.isNotEmpty && _currentStep == 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(errorMessage,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tr("already_have_account"),
                style: const TextStyle(color: Colors.white),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Text(
                  tr("login"),
                  style: const TextStyle(
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
      title: tr("name_prompt"),
      subtitle: tr("enter_username_first_last"),
      child: Column(
        children: [
          const SizedBox(height: 20),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Username", fieldName: 'username'),
            onChanged: (value) {
              setState(() {
                username = value;
                usernameCheckMessage = '';
                isCheckingUsername = false;
              });
            },
            onEditingComplete: () {
              if (username.isNotEmpty) {
                if (username.length < 4) {
                  setState(() {
                    isCheckingUsername = false;
                    usernameCheckMessage = tr("username_unavailable");
                  });
                } else {
                  _checkUsernameAvailability(username);
                }
              }
              FocusScope.of(context).nextFocus();
            },
          ),
          if (usernameCheckMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                usernameCheckMessage,
                style: TextStyle(
                  color: usernameCheckMessage == tr("username_available")
                      ? Colors.green
                      : Colors.redAccent,
                ),
              ),
            ),
          const SizedBox(height: 20),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
                tr("name_prompt").replaceAll('¿Cómo te llamas?', 'Nombre'),
                fieldName: 'firstName'),
            onChanged: (value) => firstName = value,
          ),
          const SizedBox(height: 20),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
                tr("name_prompt").replaceAll('¿Cómo te llamas?', 'Apellido'),
                fieldName: 'lastName'),
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
      title: tr("select_birthdate"),
      subtitle: tr("select_your_birthdate"),
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
                  ? tr("select_birthdate")
                  : tr("welcome") +
                      ": ${birthDate!.day}/${birthDate!.month}/${birthDate!.year}",
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
      title: tr("select_gender"),
      subtitle: tr("select_gender"),
      child: DropdownButtonFormField<String>(
        decoration:
            _dropdownDecoration(tr("select_gender"), fieldName: 'gender'),
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
      title: tr("whom_to_meet"),
      subtitle: tr("select_one_or_more"),
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
      title: tr("what_are_you_looking_for"),
      subtitle: tr("connection_purpose"),
      child: DropdownButtonFormField<String>(
        decoration: _dropdownDecoration(tr("select_objective"),
            fieldName: 'relationshipGoal'),
        style: const TextStyle(color: Colors.white),
        hint: Text(
          tr("select_objective"),
          style: const TextStyle(color: Colors.white70),
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
      title: tr("share_your_location"),
      subtitle: tr("share_your_current_location"),
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
            icon: const Icon(
              Icons.my_location,
              color: Colors.black,
            ),
            label: Text(
              location.isEmpty
                  ? tr("get_my_location")
                  : tr("location_detected"),
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
          errorMessage = tr("location_permission_denied");
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
          errorMessage = tr("could_not_determine_city");
          isLoadingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = tr("error_getting_location") + ": $e";
        isLoadingLocation = false;
      });
    }
  }

  Widget _buildStep7() {
    final gymStages = ['Volumen', 'Definición', 'Mantenimiento'];

    return _buildStepTemplate(
      title: tr("gym_stage_height_weight"),
      subtitle: tr("select_your_gym_stage_height_weight"),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            decoration: _dropdownDecoration(tr("stage"), fieldName: 'gymStage'),
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
            decoration: _inputDecoration(tr("height_cm"), fieldName: 'height'),
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
            decoration: _inputDecoration(tr("weight_kg"), fieldName: 'weight'),
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
      title: tr("profile_picture"),
      subtitle: tr("select_profile_picture"),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 75,
            backgroundImage: profilePictureFile != null
                ? FileImage(profilePictureFile!)
                : const AssetImage('assets/images/default_profile.png')
                    as ImageProvider,
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
            child: Text(
              tr("change_photo"),
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep8() {
    return _buildStepTemplate(
      title: tr("add_photos"),
      subtitle: tr("add_up_to_5_photos"),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_photo_alternate,
                      size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr("select_photos_description"),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (selectedPhotos.isNotEmpty)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(
                selectedPhotos.length,
                (index) => Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(selectedPhotos[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedPhotos.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (fieldErrors.containsKey('photos'))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                fieldErrors['photos']!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Checkbox(
                value: acceptedTerms,
                onChanged: (value) {
                  setState(() {
                    acceptedTerms = value ?? false;
                    if (acceptedTerms) {
                      fieldErrors.remove('terms');
                    }
                  });
                },
                fillColor: MaterialStateProperty.resolveWith<Color>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.blueAccent;
                    }
                    return Colors.grey;
                  },
                ),
              ),
              Expanded(
                child: Wrap(
                  children: [
                    Text(
                      tr("accept_terms"),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TermsConditionsScreen(),
                          ),
                        );
                      },
                      child: Text(
                        tr("terms_conditions"),
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tr("and"),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                      child: Text(
                        tr("privacy_policy"),
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (fieldErrors.containsKey('terms'))
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 40),
              child: Text(
                fieldErrors['terms']!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepEmailVerification() {
    return _buildStepTemplate(
      title: tr("verify_your_email"),
      subtitle: tr("enter_verification_code"),
      child: Column(
        children: [
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(tr("verification_code"),
                fieldName: 'verificationCode'),
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
                Text(tr("verify"), style: const TextStyle(color: Colors.black)),
          ),
          if (errorMessage.isNotEmpty &&
              _currentStep == emailVerificationStepIndex)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(errorMessage,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }

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
}
