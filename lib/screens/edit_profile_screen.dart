import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import '../widgets/perfil/profile_picture_widget.dart';
import '../widgets/perfil/personal_info_form.dart';
import '../widgets/perfil/additional_photos_widget.dart';
import 'login_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isUploading = false;
  String errorMessage = '';

  // Variables editables
  String firstName = '';
  String lastName = '';
  String goal = '';
  String gender = '';
  List<String> seeking = [];
  String relationshipGoal = '';

  // Variables originales
  String originalFirstName = '';
  String originalLastName = '';
  String originalGoal = '';
  String originalGender = '';
  List<String> originalSeeking = [];
  String originalRelationshipGoal = '';

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
      originalFirstName = user.firstName ?? '';
      originalLastName = user.lastName ?? '';
      originalGoal = user.goal ?? '';
      originalGender = user.gender ?? '';
      originalSeeking = List.from(user.seeking ?? []);
      originalRelationshipGoal = user.relationshipGoal ?? '';

      firstName = originalFirstName;
      lastName = originalLastName;
      goal = originalGoal;
      gender = originalGender;
      seeking = List.from(originalSeeking);
      relationshipGoal = originalRelationshipGoal;
    }
  }

  void _checkChanges() {
    setState(() {
      hasChanges = (firstName != originalFirstName ||
          lastName != originalLastName ||
          goal != originalGoal ||
          gender != originalGender ||
          relationshipGoal != originalRelationshipGoal ||
          seeking.length != originalSeeking.length ||
          !seeking.every((item) => originalSeeking.contains(item)));
    });
  }

  void _handleSeekingChanged(String option, bool isSelected) {
    setState(() {
      if (isSelected) {
        // Agregar la opción a la lista
        if (!seeking.contains(option)) {
          seeking.add(option);
        }
      } else {
        // Quitar la opción de la lista
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
          const SnackBar(
              content: Text('Puedes seleccionar un máximo de 5 fotos')),
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
          const SnackBar(
              content: Text('Fotos adicionales subidas exitosamente')),
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
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
    } else {
      return;
    }

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
      final result = await userService.updateProfile({
        'firstName': firstName,
        'lastName': lastName,
        'goal': goal,
        'gender': gender,
        'seeking': seeking, // <--- Enviamos la lista actualizada
        'relationshipGoal': relationshipGoal,
      });

      if (result['success']) {
        await authProvider.refreshUser();
        if (_photoOrderChanged && _reorderedPhotos.isNotEmpty) {
          await _updatePhotoOrder(_reorderedPhotos);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado exitosamente')),
        );

        // Actualizamos originales
        setState(() {
          originalFirstName = firstName;
          originalLastName = lastName;
          originalGoal = goal;
          originalGender = gender;
          originalSeeking = List.from(seeking);
          originalRelationshipGoal = relationshipGoal;

          hasChanges = false;
          _photoOrderChanged = false;
        });
      } else {
        setState(() {
          errorMessage = result['message'] ?? 'Error al actualizar el perfil';
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
      return const Scaffold(
        body: SizedBox(),
      );
    }

    final showSaveButton = hasChanges || _photoOrderChanged;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Editar Perfil',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 0.0),
      floatingActionButton: showSaveButton
          ? FloatingActionButton.extended(
              onPressed: _saveProfile,
              backgroundColor: Colors.blueAccent,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Guardar Cambios',
                  style: TextStyle(color: Colors.white)),
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
            const SizedBox(
                height:
                    30), // Mayor espacio entre la foto de perfil y el formulario

            // Formulario de info personal
            PersonalInfoForm(
              formKey: _formKey,
              firstName: firstName,
              lastName: lastName,
              goal: goal,
              gender: gender,
              seeking: seeking,
              relationshipGoal: relationshipGoal,
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
              onSeekingSelectionChanged: _handleSeekingChanged,
            ),

            const SizedBox(
                height:
                    30), // Mayor espacio entre el formulario y las fotos adicionales

            // Fotos adicionales
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

            // Botón de Cerrar Sesión
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  await authProvider.logoutUser();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
