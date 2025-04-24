import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:easy_localization/easy_localization.dart';

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
  // Keys para formularios
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
  int age = 18;
  int height = 0;
  int weight = 0;
  int? squatWeight;
  int? benchPressWeight;
  int? deadliftWeight;

  // Valores originales para comparar cambios
  String originalUsername = '';
  String originalFirstName = '';
  String originalLastName = '';
  String originalGoal = '';
  String originalGender = '';
  List<String> originalSeeking = [];
  String originalRelationshipGoal = '';
  String originalBiography = '';
  int originalAge = 18;
  int originalHeight = 0;
  int originalWeight = 0;
  int? originalSquatWeight;
  int? originalBenchPressWeight;
  int? originalDeadliftWeight;

  String location = '';
  double? userLatitude;
  double? userLongitude;
  bool isLoadingLocation = false;
  bool locationUpdated = false;

  bool hasChanges = false;
  late final TextEditingController _locationController;
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
    _locationController = TextEditingController(text: location);
    if (user != null) {
      // --- inicializar todos los campos desde user ---
      username = originalUsername = user.username ?? '';
      originalFirstName = user.firstName ?? '';
      originalLastName = user.lastName ?? '';
      originalGoal = user.goal ?? '';
      originalGender = user.gender ?? '';
      originalSeeking = List.from(user.seeking ?? []);
      originalRelationshipGoal = user.relationshipGoal ?? '';
      originalBiography = user.biography ?? '';
      originalAge = user.age ?? 18;
      originalHeight = user.height ?? 0;
      originalWeight = user.weight ?? 0;
      originalSquatWeight = user.squatWeight;
      originalBenchPressWeight = user.benchPressWeight;
      originalDeadliftWeight = user.deadliftWeight;

      firstName = originalFirstName;
      lastName = originalLastName;
      goal = originalGoal;
      gender = originalGender;
      seeking = List.from(originalSeeking);
      relationshipGoal = originalRelationshipGoal;
      biography = originalBiography;
      age = originalAge;
      height = originalHeight;
      weight = originalWeight;
      squatWeight = originalSquatWeight;
      benchPressWeight = originalBenchPressWeight;
      deadliftWeight = originalDeadliftWeight;

      if ((user.city?.isNotEmpty ?? false) ||
          (user.country?.isNotEmpty ?? false)) {
        location = '${user.city}, ${user.country}';
        _locationController.text = location;
      }
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
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
          age != originalAge ||
          height != originalHeight ||
          weight != originalWeight ||
          squatWeight != originalSquatWeight ||
          benchPressWeight != originalBenchPressWeight ||
          deadliftWeight != originalDeadliftWeight ||
          seeking.length != originalSeeking.length ||
          !seeking.every(originalSeeking.contains) ||
          locationUpdated);
    });
  }

  Future<void> _obtenerUbicacion() async {
    setState(() {
      isLoadingLocation = true;
      errorMessage = '';
    });
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          errorMessage = tr("location_permission_denied");
          isLoadingLocation = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final nueva = '${p.locality ?? ''}, ${p.country ?? ''}';
        setState(() {
          location = nueva;
          _locationController.text = nueva;
          userLatitude = pos.latitude;
          userLongitude = pos.longitude;
          locationUpdated = true;
          isLoadingLocation = false;
        });
        _checkChanges();
      } else {
        setState(() {
          errorMessage = tr("could_not_determine_city");
          isLoadingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = '${tr("error_getting_location")}: $e';
        isLoadingLocation = false;
      });
    }
  }

  void _handleSeekingChanged(String option, bool isSelected) {
    setState(() {
      if (isSelected)
        seeking.add(option);
      else
        seeking.remove(option);
    });
    _checkChanges();
  }

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
      await _uploadProfilePicture();
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_imageFile == null) return;
    setState(() {
      isUploading = true;
      errorMessage = '';
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.getToken();
    if (token == null) {
      setState(() {
        isUploading = false;
        errorMessage = tr("token_not_found_login");
      });
      return;
    }
    try {
      final svc = UserService(token: token);
      final res = await svc.uploadProfilePicture(_imageFile!);
      if (res['success']) {
        await auth.refreshUser();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr("profile_updated_successfully")),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        setState(() => _imageFile = null);
      } else {
        setState(() => errorMessage =
            res['message'] ?? tr("error_uploading_profile_picture"));
      }
    } catch (e) {
      setState(
          () => errorMessage = '${tr("error_uploading_profile_picture")}: $e');
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _pickAdditionalImages() async {
    final picked =
        await _picker.pickMultiImage(maxWidth: 1080, maxHeight: 1080);
    if (picked != null) {
      if (picked.length > 5) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr("max_5_photos"))));
        return;
      }
      setState(
          () => _additionalImages = picked.map((f) => File(f.path)).toList());
    }
  }

  Future<void> _uploadAdditionalPhotos() async {
    if (_additionalImages.isEmpty) return;
    setState(() {
      isUploading = true;
      errorMessage = '';
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.getToken();
    if (token == null) {
      setState(() {
        isUploading = false;
        errorMessage = tr("token_not_found_login");
      });
      return;
    }
    try {
      final svc = UserService(token: token);
      final res = await svc.uploadPhotos(_additionalImages);
      if (res['success']) {
        await auth.refreshUser();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr("additional_photos_uploaded_successfully"))),
        );
        setState(() => _additionalImages = []);
      } else {
        setState(() => errorMessage =
            res['message'] ?? tr("error_uploading_additional_photos"));
      }
    } catch (e) {
      setState(() =>
          errorMessage = '${tr("error_uploading_additional_photos")}: $e');
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _updatePhotoOrder(List<Photo> newList) async {
    if (newList.isEmpty) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.getToken();
    if (token == null) return;
    final svc = UserService(token: token);
    final ids = newList.map((p) => p.id).toList();
    final res = await svc.updatePhotoOrder(ids);
    if (res['success'] == true) {
      await auth.refreshUser();
    } else {
      setState(() =>
          errorMessage = res['message'] ?? tr("error_updating_photo_order"));
    }
  }

  Future<void> _saveProfile() async {
    if (!_usernameFormKey.currentState!.validate() ||
        !_personalInfoFormKey.currentState!.validate()) return;

    _usernameFormKey.currentState!.save();
    _personalInfoFormKey.currentState!.save();

    setState(() {
      isUploading = true;
      errorMessage = '';
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = await auth.getToken();
      if (token == null) {
        setState(() => errorMessage = tr("token_not_found_login"));
        return;
      }
      final svc = UserService(token: token);

      // 1) Username si cambió
      if (username != auth.user?.username) {
        final usrRes = await svc.updateUsername(username);
        if (!usrRes['success']) {
          setState(
              () => errorMessage = usrRes['message'] ?? tr("enter_username"));
          return;
        }
      }

      // 2) Perfil general
      final profileData = {
        'firstName': firstName,
        'lastName': lastName,
        'goal': goal,
        'gender': gender,
        'seeking': seeking,
        'relationshipGoal': relationshipGoal,
        'biography': biography,
        'age': age,
        'height': height,
        'weight': weight,
        'squatWeight': squatWeight,
        'benchPressWeight': benchPressWeight,
        'deadliftWeight': deadliftWeight,
        if (locationUpdated && userLatitude != null && userLongitude != null)
          'location': {
            'type': 'Point',
            'coordinates': [userLongitude, userLatitude],
          },
      };
      final res = await svc.updateProfile(profileData);
      if (!res['success']) {
        setState(() =>
            errorMessage = res['message'] ?? tr("error_updating_profile"));
        return;
      }

      // 3) Si reordenó fotos, persistir también ese cambio
      if (_photoOrderChanged) {
        await _updatePhotoOrder(_reorderedPhotos);
        _photoOrderChanged = false;
      }

      // 4) Refrescar y cerrar
      await auth.refreshUser();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr("profile_updated_successfully")),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => hasChanges = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyProfileScreen()),
      );
    } catch (e) {
      setState(() => errorMessage = '${tr("error_updating_profile")}: $e');
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _deletePhoto(String publicId) async {
    setState(() {
      isUploading = true;
      errorMessage = '';
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.getToken();
    if (token == null) {
      setState(() {
        isUploading = false;
        errorMessage = tr("token_not_found_login");
      });
      return;
    }
    final svc = UserService(token: token);
    final res = await svc.deletePhoto(publicId);
    if (res['success'] == true) {
      await auth.refreshUser();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("photo_deleted_successfully"))),
      );
    } else {
      setState(
          () => errorMessage = res['message'] ?? tr("error_deleting_photo"));
    }
    setState(() => isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    if (user == null) {
      Future.microtask(() {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      });
      return const Scaffold(body: SizedBox());
    }

    final showSave = hasChanges || _photoOrderChanged;
    final sectionHeaderStyle = TextStyle(
      color: Colors.white70,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(tr("edit_profile"),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 0),
      floatingActionButton: showSave
          ? FloatingActionButton.extended(
              onPressed: isUploading ? null : _saveProfile,
              backgroundColor: Colors.blueAccent,
              icon: isUploading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(isUploading ? tr("saving") : tr("save_changes"),
                  style: const TextStyle(color: Colors.white)),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfilePictureWidget(
                user: user,
                imageFile: _imageFile,
                onPickImage: _pickProfileImage),
            const SizedBox(height: 16),
            Text(tr("basic_information"), style: sectionHeaderStyle),
            const SizedBox(height: 8),
            Form(
              key: _usernameFormKey,
              child: TextFormField(
                initialValue: username,
                decoration: InputDecoration(
                  labelText: tr("username"),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  filled: true,
                  fillColor: Colors.white12,
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white54),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.blueAccent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorStyle: const TextStyle(color: Colors.redAccent),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (v) {
                  username = v;
                  _checkChanges();
                },
                validator: (v) =>
                    (v == null || v.isEmpty) ? tr("enter_username") : null,
              ),
            ),

            const SizedBox(height: 24),
            PersonalInfoForm(
              formKey: _personalInfoFormKey,
              firstName: firstName,
              lastName: lastName,
              goal: goal,
              gender: gender,
              seeking: seeking,
              relationshipGoal: relationshipGoal,
              biography: biography,
              age: age,
              height: height,
              weight: weight,
              onFirstNameChanged: (v) {
                firstName = v;
                _checkChanges();
              },
              onLastNameChanged: (v) {
                lastName = v;
                _checkChanges();
              },
              onGoalChanged: (v) {
                goal = v ?? '';
                _checkChanges();
              },
              onGenderChanged: (v) {
                gender = v ?? '';
                _checkChanges();
              },
              onRelationshipGoalChanged: (v) {
                relationshipGoal = v ?? '';
                _checkChanges();
              },
              onBiographyChanged: (v) {
                biography = v;
                _checkChanges();
              },
              onAgeChanged: (v) {
                age = v;
                _checkChanges();
              },
              onHeightChanged: (v) {
                height = v;
                _checkChanges();
              },
              onWeightChanged: (v) {
                weight = v;
                _checkChanges();
              },
              onSeekingSelectionChanged: _handleSeekingChanged,
            ),

            const SizedBox(height: 24),
            Text(tr("biography_location"), style: sectionHeaderStyle),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: tr("location"),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: Colors.white12,
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white54),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: isLoadingLocation
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _obtenerUbicacion,
                      ),
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),
            Text(tr("basic_lifts"), style: sectionHeaderStyle),
            const SizedBox(height: 8),
            // sentadilla
            TextFormField(
              initialValue: squatWeight?.toString() ?? '',
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr("squat_kg"),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: Colors.white12,
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white54),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) {
                squatWeight = int.tryParse(v);
                _checkChanges();
              },
            ),
            const SizedBox(height: 16),
            // press banca
            TextFormField(
              initialValue: benchPressWeight?.toString() ?? '',
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr("bench_press_kg"),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: Colors.white12,
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white54),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) {
                benchPressWeight = int.tryParse(v);
                _checkChanges();
              },
            ),
            const SizedBox(height: 16),
            // peso muerto
            TextFormField(
              initialValue: deadliftWeight?.toString() ?? '',
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr("deadlift_kg"),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: Colors.white12,
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white54),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) {
                deadliftWeight = int.tryParse(v);
                _checkChanges();
              },
            ),

            const SizedBox(height: 24),
            Text(tr("photos"), style: sectionHeaderStyle),
            const SizedBox(height: 8),
            AdditionalPhotosWidget(
              user: user,
              additionalImages: _additionalImages,
              isUploading: isUploading,
              onPickAdditionalImages: _pickAdditionalImages,
              onUploadAdditionalPhotos: _uploadAdditionalPhotos,
              onRemoveSelectedImage: (i) =>
                  setState(() => _additionalImages.removeAt(i)),
              onDeletePhoto: _deletePhoto,
              onReorderDone: (newList) {
                setState(() {
                  _reorderedPhotos = newList;
                  _photoOrderChanged = true;
                });
              },
            ),

            if (errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(errorMessage,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
