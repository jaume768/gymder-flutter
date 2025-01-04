// lib/screens/profile_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isEditing = false;
  bool isUploading = false;
  String errorMessage = '';

  // Campos editables
  String firstName = '';
  String lastName = '';
  String goal = '';
  String gender = '';
  List<String> seeking = [];
  String relationshipGoal = '';

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
      firstName = user.firstName ?? '';
      lastName = user.lastName ?? '';
      goal = user.goal ?? '';
      gender = user.gender ?? '';
      seeking = user.seeking ?? [];
      relationshipGoal = user.relationshipGoal ?? '';
    }
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
        // Actualizar el usuario en el AuthProvider
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
      // Limitar a máximo 5 fotos
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
        // Actualizar el usuario en el AuthProvider
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
        // Actualizar el usuario en el AuthProvider
        await authProvider.refreshUser();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado exitosamente')),
        );

        setState(() {
          isEditing = false;
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

  // Widget para mostrar fotos adicionales
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
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
                if (isEditing)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () async {
                        // Implementar eliminación de la foto
                        await _deletePhoto(photo.publicId);
                      },
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.red,
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        if (isEditing && photos.length < 5)
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
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
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
        // Actualizar el usuario en el AuthProvider
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
      return const Center(child: Text('Usuario no encontrado.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: const Color.fromRGBO(64, 65, 65, 1),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            tooltip: isEditing ? 'Guardar' : 'Editar',
            onPressed: () {
              if (isEditing) {
                _saveProfile();
              } else {
                setState(() {
                  isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      backgroundColor: const Color.fromRGBO(64, 65, 65, 1),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Foto de Perfil
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : (user.profilePicture != null
                      ? CachedNetworkImageProvider(user.profilePicture!.url)
                      : const AssetImage('assets/images/default_profile.png') as ImageProvider),
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
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Botón para subir foto de perfil (solo en modo edición)
            if (isEditing && _imageFile != null)
              ElevatedButton(
                onPressed: isUploading ? null : _uploadProfilePicture,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, // Fondo blanco
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: isUploading
                    ? const CircularProgressIndicator(
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.black),
                )
                    : const Text(
                  'Subir Foto de Perfil',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            // Formulario de Perfil
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Nombre
                  TextFormField(
                    initialValue: firstName,
                    enabled: isEditing,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      labelStyle: const TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      errorStyle: const TextStyle(color: Colors.redAccent),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu nombre';
                      }
                      return null;
                    },
                    onSaved: (value) => firstName = value!,
                    cursorColor: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  // Apellido
                  TextFormField(
                    initialValue: lastName,
                    enabled: isEditing,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Apellido',
                      labelStyle: const TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      errorStyle: const TextStyle(color: Colors.redAccent),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu apellido';
                      }
                      return null;
                    },
                    onSaved: (value) => lastName = value!,
                    cursorColor: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  // Objetivo
                  TextFormField(
                    initialValue: goal,
                    enabled: isEditing,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Objetivo',
                      labelStyle: const TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      errorStyle: const TextStyle(color: Colors.redAccent),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu objetivo';
                      }
                      return null;
                    },
                    onSaved: (value) => goal = value!,
                    cursorColor: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  // Género
                  DropdownButtonFormField<String>(
                    value: gender.isNotEmpty ? gender : null,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Género',
                      labelStyle: const TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      errorStyle: const TextStyle(color: Colors.redAccent),
                    ),
                    items: [
                      'Masculino',
                      'Femenino',
                      'No Binario',
                      'Prefiero no decirlo',
                      'Otro'
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: isEditing
                        ? (String? newValue) {
                      setState(() {
                        gender = newValue!;
                      });
                    }
                        : null,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor selecciona tu género';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Buscando
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Buscando:',
                      style: TextStyle(color: Colors.white.withOpacity(0.9)),
                    ),
                  ),
                  const SizedBox(height: 10),
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
                        label: Text(
                          option,
                          style: const TextStyle(color: Colors.black),
                        ),
                        selected: seeking.contains(option),
                        backgroundColor: Colors.white54,
                        selectedColor: Colors.white,
                        onSelected: isEditing
                            ? (bool selected) {
                          setState(() {
                            if (selected) {
                              seeking.add(option);
                            } else {
                              seeking.remove(option);
                            }
                          });
                        }
                            : null,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  // Objetivo de Relación
                  DropdownButtonFormField<String>(
                    value: relationshipGoal.isNotEmpty ? relationshipGoal : null,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Objetivo de Relación',
                      labelStyle: const TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      errorStyle: const TextStyle(color: Colors.redAccent),
                    ),
                    items: [
                      'Amistad',
                      'Relación',
                      'Casual',
                      'Otro'
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: isEditing
                        ? (String? newValue) {
                      setState(() {
                        relationshipGoal = newValue!;
                      });
                    }
                        : null,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor selecciona un objetivo de relación';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  // Botón para Subir Foto de Perfil (Solo en modo edición)
                  if (isEditing && _imageFile != null)
                    ElevatedButton(
                      onPressed: isUploading ? null : _uploadProfilePicture,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // Fondo blanco
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: isUploading
                          ? const CircularProgressIndicator(
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.black),
                      )
                          : const Text(
                        'Subir Foto de Perfil',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Fotos Adicionales
                  _buildAdditionalPhotos(user),
                  const SizedBox(height: 20),
                  // Mensaje de Error
                  if (errorMessage.isNotEmpty)
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
