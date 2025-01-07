// lib/screens/profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isUploading = false;
  String errorMessage = '';

  // -- Variables "editables" para el formulario --
  String firstName = '';
  String lastName = '';
  String goal = '';
  String gender = '';
  List<String> seeking = [];
  String relationshipGoal = '';

  // -- Variables "originales" para comparar cambios --
  String originalFirstName = '';
  String originalLastName = '';
  String originalGoal = '';
  String originalGender = '';
  List<String> originalSeeking = [];
  String originalRelationshipGoal = '';

  // Indica si hubo cambios en cualquier campo
  bool hasChanges = false;

  // Imagen seleccionada para subir (foto de perfil)
  File? _imageFile;
  // Fotos adicionales seleccionadas para subir
  List<File> _additionalImages = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      // Guardar valores originales
      originalFirstName = user.firstName ?? '';
      originalLastName = user.lastName ?? '';
      originalGoal = user.goal ?? '';
      originalGender = user.gender ?? '';
      originalSeeking = List.from(user.seeking ?? []);
      originalRelationshipGoal = user.relationshipGoal ?? '';

      // Inicializar valores editables con valores originales
      firstName = originalFirstName;
      lastName = originalLastName;
      goal = originalGoal;
      gender = originalGender;
      seeking = List.from(originalSeeking);
      relationshipGoal = originalRelationshipGoal;
    }
  }

  /// Verifica si los valores actuales difieren de los originales
  void _checkChanges() {
    setState(() {
      hasChanges = (
          firstName != originalFirstName ||
              lastName != originalLastName ||
              goal != originalGoal ||
              gender != originalGender ||
              relationshipGoal != originalRelationshipGoal ||
              // Comparación de listas (seeking)
              seeking.length != originalSeeking.length ||
              !seeking.every((item) => originalSeeking.contains(item))
      );
    });
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
      // Subir la imagen inmediatamente tras seleccionarla
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
        errorMessage = 'Token no encontrado. Por favor, inicia sesión nuevamente.';
      });
      return;
    }
    try {
      final userService = UserService(token: token);
      final result = await userService.uploadProfilePicture(_imageFile!);
      if (result['success']) {
        await authProvider.refreshUser();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada exitosamente')),
        );
        setState(() {
          _imageFile = null;
        });
      } else {
        setState(() {
          errorMessage = result['message'] ?? 'Error al subir la foto de perfil';
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
        _additionalImages = pickedFiles.map((pickedFile) => File(pickedFile.path)).toList();
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
        errorMessage = 'Token no encontrado. Por favor, inicia sesión nuevamente.';
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
          errorMessage = result['message'] ?? 'Error al subir fotos adicionales';
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      isUploading = true;
      errorMessage = '';
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    if (token == null) {
      setState(() {
        isUploading = false;
        errorMessage = 'Token no encontrado. Por favor, inicia sesión nuevamente.';
      });
      return;
    }

    try {
      final userService = UserService(token: token);
      final result = await userService.updateProfile({
        'firstName': firstName,
        'lastName': lastName,
        'goal': goal,
        'gender': gender,
        'seeking': seeking,
        'relationshipGoal': relationshipGoal,
      });
      if (result['success']) {
        await authProvider.refreshUser();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado exitosamente')),
        );

        // Al guardar, actualizamos también los valores originales
        setState(() {
          originalFirstName = firstName;
          originalLastName = lastName;
          originalGoal = goal;
          originalGender = gender;
          originalSeeking = List.from(seeking);
          originalRelationshipGoal = relationshipGoal;
          hasChanges = false; // Se resetea porque ya se guardó
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
        errorMessage = 'Token no encontrado. Por favor, inicia sesión nuevamente.';
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

  Widget _buildProfilePicture(User user) {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 70,
            backgroundColor: Colors.white,
            backgroundImage: _imageFile != null
                ? FileImage(_imageFile!)
                : (user.profilePicture != null
                ? CachedNetworkImageProvider(user.profilePicture!.url)
                : const AssetImage('assets/images/default_profile.png')
            as ImageProvider),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: _pickProfileImage,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                padding: const EdgeInsets.all(8),
                child:
                const Icon(Icons.camera_alt, color: Colors.black, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoForm() {
    return Card(
      color: const Color.fromRGBO(64, 65, 65, 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(
                label: 'Nombre',
                initialValue: firstName,
                enabled: true,
                onSaved: (value) => firstName = value!,
                validatorMsg: 'Por favor ingresa tu nombre',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Apellido',
                initialValue: lastName,
                enabled: true,
                onSaved: (value) => lastName = value!,
                validatorMsg: 'Por favor ingresa tu apellido',
              ),
              const SizedBox(height: 16),

              /// Conviértelo a Dropdown para "Objetivo"
              _buildDropdownField(
                label: 'Objetivo',
                value: goal.isNotEmpty ? goal : null,
                items: const ['Definición', 'Volumen', 'Mantenimiento'],
                enabled: true,
                onChanged: (val) {
                  setState(() {
                    goal = val!;
                  });
                  _checkChanges();
                },
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
                enabled: true,
                onChanged: (val) {
                  setState(() {
                    gender = val!;
                  });
                  _checkChanges();
                },
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
                  return FilterChip(
                    label: Text(option, style: const TextStyle(color: Colors.black)),
                    selected: seeking.contains(option),
                    backgroundColor: Colors.white54,
                    selectedColor: Colors.white,
                    onSelected: (selected) {
                      setState(() {
                        selected ? seeking.add(option) : seeking.remove(option);
                      });
                      _checkChanges();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              _buildDropdownField(
                label: 'Objetivo de Relación',
                value: relationshipGoal.isNotEmpty ? relationshipGoal : null,
                items: const ['Amistad', 'Relación', 'Casual', 'Otro'],
                enabled: true,
                onChanged: (val) {
                  setState(() {
                    relationshipGoal = val!;
                  });
                  _checkChanges();
                },
                validatorMsg: 'Por favor selecciona un objetivo de relación',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String initialValue,
    required bool enabled,
    required FormFieldSetter<String> onSaved,
    required String validatorMsg,
  }) {
    return TextFormField(
      initialValue: initialValue,
      enabled: enabled,
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
      onSaved: onSaved,
      onChanged: (value) {
        setState(() {
          onSaved(value); // actualiza la variable local (firstName, lastName, etc.)
        });
        _checkChanges();
      },
      cursorColor: Colors.white,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required bool enabled,
    required ValueChanged<String?> onChanged,
    required String validatorMsg,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      // Estilo del texto para la opción seleccionada
      style: const TextStyle(color: Colors.white),
      // Opciones desplegadas en negro; la seleccionada en blanco
      selectedItemBuilder: (BuildContext context) {
        return items.map<Widget>((String item) {
          return Text(
            item,
            style: const TextStyle(color: Colors.white),
          );
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
      onChanged: enabled ? onChanged : null,
      validator: (value) =>
      (value == null || value.isEmpty) ? validatorMsg : null,
    );
  }

  Widget _buildAdditionalPhotos(User user) {
    final photos = user.photos ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fotos Adicionales:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        photos.isEmpty
            ? const Text(
          'No tienes fotos adicionales.',
          style: TextStyle(color: Colors.white70),
        )
            : GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
          ),
          itemBuilder: (context, index) {
            final photo = photos[index];
            return Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: photo.url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                  ),
                  errorWidget: (context, url, error) =>
                  const Icon(Icons.error),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () async {
                      await _deletePhoto(photo.publicId);
                    },
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.red,
                      child:
                      Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _pickAdditionalImages,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Agregar Fotos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            if (_additionalImages.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fotos Seleccionadas:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _additionalImages.length,
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 5,
                    ),
                    itemBuilder: (context, index) {
                      final file = _additionalImages[index];
                      return Stack(
                        children: [
                          Image.file(
                            file,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _additionalImages.removeAt(index);
                                });
                              },
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: Icon(Icons.close,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: isUploading ? null : _uploadAdditionalPhotos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: isUploading
                        ? const CircularProgressIndicator(
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.black),
                    )
                        : const Text(
                      'Subir Fotos Adicionales',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return const Center(child: Text('Usuario no encontrado.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: const Color.fromRGBO(64, 65, 65, 1),
      ),
      backgroundColor: const Color.fromRGBO(64, 65, 65, 1),

      // Solo mostramos el FAB si hay cambios
      floatingActionButton: hasChanges
          ? FloatingActionButton.extended(
        onPressed: _saveProfile,
        backgroundColor: Colors.white,
        icon: const Icon(Icons.save, color: Colors.black),
        label: const Text('Guardar Cambios',
            style: TextStyle(color: Colors.black)),
      )
          : null,

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProfilePicture(user),
            const SizedBox(height: 20),
            _buildPersonalInfoForm(),
            const SizedBox(height: 20),
            _buildAdditionalPhotos(user),
            if (errorMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
