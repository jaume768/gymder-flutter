import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import '../widgets/perfil/profile_picture_widget.dart';
import '../widgets/perfil/personal_info_form.dart';
import '../widgets/perfil/additional_photos_widget.dart';
import 'login_screen.dart';
import 'my_profile_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Keys distintas para cada Form
  final _usernameFormKey = GlobalKey<FormState>();
  final _personalInfoFormKey = GlobalKey<FormState>();

  bool isUploading = false;
  String errorMessage = '';

  // Variables editables
  String username = '';
  String firstName = '';
  String lastName = '';
  String goal = '';
  String gender = '';
  List<String> seeking = [];
  String relationshipGoal = '';
  String biography = '';

  // Valores originales para comparar cambios
  String originalUsername = '';
  String originalFirstName = '';
  String originalLastName = '';
  String originalGoal = '';
  String originalGender = '';
  List<String> originalSeeking = [];
  String originalRelationshipGoal = '';
  String originalBiography = '';

  String location = '';
  double? userLatitude;
  double? userLongitude;
  bool isLoadingLocation = false;
  bool locationUpdated = false;

  bool hasChanges = false;
  File? _imageFile;
  List<File> _additionalImages = [];
  final ImagePicker _picker = ImagePicker();

  // Control de reordenamiento de fotos
  List<Photo> _reorderedPhotos = [];
  bool _photoOrderChanged = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      username = user.username ?? '';
      originalUsername = user.username ?? '';
      if ((user.city != null && user.city!.isNotEmpty) ||
          (user.country != null && user.country!.isNotEmpty)) {
        location = '${user.city ?? ''}, ${user.country ?? ''}';
      }
      originalFirstName = user.firstName ?? '';
      originalLastName = user.lastName ?? '';
      originalGoal = user.goal ?? '';
      originalGender = user.gender ?? '';
      originalSeeking = List.from(user.seeking ?? []);
      originalRelationshipGoal = user.relationshipGoal ?? '';
      originalBiography = user.biography ?? '';
      // Asignamos los valores a las variables editables
      firstName = originalFirstName;
      lastName = originalLastName;
      goal = originalGoal;
      gender = originalGender;
      seeking = List.from(originalSeeking);
      relationshipGoal = originalRelationshipGoal;
      biography = originalBiography;
    }
  }

  void _checkChanges() {
    setState(() {
      hasChanges = (username != originalUsername ||
          firstName != originalFirstName ||
          lastName != originalLastName ||
          goal != originalGoal ||
          gender != originalGender ||
          relationshipGoal != originalRelationshipGoal ||
          biography != originalBiography ||
          seeking.length != originalSeeking.length ||
          !seeking.every((item) => originalSeeking.contains(item)) ||
          locationUpdated);
    });
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
          locationUpdated = true;
        });
        _checkChanges();
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

  void _handleSeekingChanged(String option, bool isSelected) {
    setState(() {
      if (isSelected) {
        if (!seeking.contains(option)) {
          seeking.add(option);
        }
      } else {
        seeking.remove(option);
      }
    });
    _checkChanges();
  }

  Future<void> _pickProfileImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      await _uploadProfilePicture();
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_imageFile == null) return;
    setState(() {
      isUploading = true;
      errorMessage = '';
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) {
      setState(() {
        isUploading = false;
        errorMessage = 'Token no encontrado. Inicia sesión nuevamente.';
      });
      return;
    }
    try {
      final userService = UserService(token: token);
      final result = await userService.uploadProfilePicture(_imageFile!);
      if (result['success']) {
        await authProvider.refreshUser();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Perfil actualizado exitosamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        );
        setState(() {
          _imageFile = null;
        });
      } else {
        setState(() {
          errorMessage =
              result['message'] ?? 'Error al subir la foto de perfil';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error al subir la foto de perfil: $e';
      });
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  Future<void> _pickAdditionalImages() async {
    final pickedFiles = await _picker.pickMultiImage(
      maxWidth: 10800,
      maxHeight: 10800,
    );
    if (pickedFiles != null) {
      if (pickedFiles.length > 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Puedes seleccionar un máximo de 5 fotos')),
        );
        return;
      }
      setState(() {
        _additionalImages = pickedFiles.map((f) => File(f.path)).toList();
      });
    }
  }

  Future<void> _uploadAdditionalPhotos() async {
    if (_additionalImages.isEmpty) return;
    setState(() {
      isUploading = true;
      errorMessage = '';
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) {
      setState(() {
        isUploading = false;
        errorMessage = 'Token no encontrado. Inicia sesión nuevamente.';
      });
      return;
    }
    try {
      final userService = UserService(token: token);
      final result = await userService.uploadPhotos(_additionalImages);
      if (result['success']) {
        await authProvider.refreshUser();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotos adicionales subidas exitosamente')),
        );
        setState(() {
          _additionalImages = [];
        });
      } else {
        setState(() {
          errorMessage =
              result['message'] ?? 'Error al subir fotos adicionales';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error al subir fotos adicionales: $e';
      });
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  Future<void> _updatePhotoOrder(List<Photo> newPhotoList) async {
    if (newPhotoList.isEmpty) return;
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) return;
      final userService = UserService(token: token);
      final photoIds = newPhotoList.map((p) => p.id).toList();
      final result = await userService.updatePhotoOrder(photoIds);
      if (result['success'] == true) {
        await authProvider.refreshUser();
      } else {
        setState(() {
          errorMessage =
              result['message'] ?? 'Error al actualizar orden de fotos';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error al actualizar orden de fotos: $e';
      });
    }
  }

  Future<void> _saveProfile() async {
    // Validamos ambos formularios
    if (!_usernameFormKey.currentState!.validate() ||
        !_personalInfoFormKey.currentState!.validate()) {
      return;
    }
    _usernameFormKey.currentState!.save();
    _personalInfoFormKey.currentState!.save();

    setState(() {
      isUploading = true;
      errorMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) {
        setState(() {
          errorMessage = 'Token no encontrado. Inicia sesión nuevamente.';
        });
        return;
      }
      final userService = UserService(token: token);
      Map<String, dynamic> profileData = {
        'firstName': firstName,
        'lastName': lastName,
        'goal': goal,
        'gender': gender,
        'seeking': seeking,
        'relationshipGoal': relationshipGoal,
        'biography': biography,
      };

      // Si el username cambió, se intenta actualizarlo en el backend
      if (username != authProvider.user?.username) {
        final usernameResponse = await userService.updateUsername(username);
        if (!usernameResponse['success']) {
          setState(() {
            errorMessage = usernameResponse['message'];
          });
          return;
        }
      }

      final result = await userService.updateProfile(profileData);
      if (result['success']) {
        await authProvider.refreshUser();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Perfil actualizado exitosamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        );
        setState(() {
          hasChanges = false;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyProfileScreen()),
        );
      } else {
        setState(() {
          errorMessage = result['message'];
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error al actualizar el perfil: $e';
      });
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  Future<void> _deletePhoto(String publicId) async {
    setState(() {
      isUploading = true;
      errorMessage = '';
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) {
      setState(() {
        isUploading = false;
        errorMessage = 'Token no encontrado. Inicia sesión nuevamente.';
      });
      return;
    }
    try {
      final userService = UserService(token: token);
      final result = await userService.deletePhoto(publicId);
      if (result['success']) {
        await authProvider.refreshUser();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto eliminada exitosamente')),
        );
      } else {
        setState(() {
          errorMessage = result['message'] ?? 'Error al eliminar la foto';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error al eliminar la foto: $e';
      });
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    if (user == null) {
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
      return const Scaffold(body: SizedBox());
    }
    final showSaveButton = hasChanges || _photoOrderChanged;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 0.0),
      floatingActionButton: showSaveButton
          ? FloatingActionButton.extended(
        onPressed: isUploading ? null : _saveProfile,
        backgroundColor: Colors.blueAccent,
        icon: isUploading
            ? const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : const Icon(Icons.save, color: Colors.white),
        label: Text(
          isUploading ? 'Guardando...' : 'Guardar Cambios',
          style: const TextStyle(color: Colors.white),
        ),
      )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfilePictureWidget(
              user: user,
              imageFile: _imageFile,
              onPickImage: _pickProfileImage,
            ),
            const SizedBox(height: 30),
            // Form para el username
            Form(
              key: _usernameFormKey,
              child: TextFormField(
                initialValue: username,
                decoration: InputDecoration(
                  labelText: 'Username',
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
                style: const TextStyle(color: Colors.white),
                onChanged: (val) {
                  username = val;
                  _checkChanges();
                },
                validator: (value) =>
                (value == null || value.isEmpty) ? 'Ingresa un username' : null,
              ),
            ),
            const SizedBox(height: 30),
            // PersonalInfoForm para el resto de la información
            PersonalInfoForm(
              formKey: _personalInfoFormKey,
              firstName: firstName,
              lastName: lastName,
              goal: goal,
              gender: gender,
              seeking: seeking,
              relationshipGoal: relationshipGoal,
              biography: biography,
              onFirstNameChanged: (val) {
                firstName = val;
                _checkChanges();
              },
              onLastNameChanged: (val) {
                lastName = val;
                _checkChanges();
              },
              onGoalChanged: (val) {
                if (val != null) {
                  goal = val;
                  _checkChanges();
                }
              },
              onGenderChanged: (val) {
                if (val != null) {
                  gender = val;
                  _checkChanges();
                }
              },
              onRelationshipGoalChanged: (val) {
                if (val != null) {
                  relationshipGoal = val;
                  _checkChanges();
                }
              },
              onBiographyChanged: (val) {
                biography = val;
                _checkChanges();
              },
              onSeekingSelectionChanged: _handleSeekingChanged,
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.white24,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: ListTile(
                leading: const Icon(Icons.location_on, color: Colors.white, size: 30),
                title: isLoadingLocation
                    ? const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
                    : Text(
                  location.isNotEmpty ? location : 'Ubicación no definida',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _obtenerUbicacion,
                ),
              ),
            ),
            const SizedBox(height: 30),
            AdditionalPhotosWidget(
              user: user,
              additionalImages: _additionalImages,
              isUploading: isUploading,
              onPickAdditionalImages: _pickAdditionalImages,
              onUploadAdditionalPhotos: _uploadAdditionalPhotos,
              onRemoveSelectedImage: (index) {
                setState(() {
                  _additionalImages.removeAt(index);
                });
              },
              onDeletePhoto: _deletePhoto,
              onReorderDone: (List<Photo> newPhotoList) {
                _reorderedPhotos = newPhotoList;
                _photoOrderChanged = true;
                setState(() {});
              },
            ),
            if (errorMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
