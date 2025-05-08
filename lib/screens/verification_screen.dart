import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({Key? key}) : super(key: key);

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _isLoading = true;
  String _verificationStatus = 'false';
  bool _hasIdentityDocument = false;
  bool _hasSelfie = false;
  File? _identityDocumentFile;
  File? _selfieFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('not_logged_in'))),
        );
        Navigator.of(context).pop();
        return;
      }

      final userService = UserService(token: token);
      final result = await userService.getVerificationStatus();

      if (result['success'] == true) {
        setState(() {
          _verificationStatus = result['verificationStatus'] ?? 'false';
          _hasIdentityDocument = result['hasIdentityDocument'] ?? false;
          _hasSelfie = result['hasSelfieWithDocument'] ?? false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? tr('error'))),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('error_getting_verification_status'))),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source, bool isIdentityDocument) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source, 
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile != null) {
        setState(() {
          if (isIdentityDocument) {
            _identityDocumentFile = File(pickedFile.path);
          } else {
            _selfieFile = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Mostrar diálogo para elegir fuente de imagen (cámara o galería)
  void _showImageSourceActionSheet(bool isIdentityDocument) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: Text(tr('take_photo'), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera, isIdentityDocument);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: Text(tr('select_from_gallery'), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery, isIdentityDocument);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadIdentityDocument() async {
    if (_identityDocumentFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('select_document_first'))),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('not_logged_in'))),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final userService = UserService(token: token);
      final result = await userService.uploadIdentityDocument(_identityDocumentFile!);

      if (result['success'] != false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('document_uploaded'))),
        );
        await _loadVerificationStatus(); // Actualizar el estado
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? tr('error_uploading_document'))),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('error_uploading_document')}: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadSelfieWithDocument() async {
    if (_selfieFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('select_selfie_first'))),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('not_logged_in'))),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final userService = UserService(token: token);
      final result = await userService.uploadSelfieWithDocument(_selfieFile!);

      if (result['success'] != false) {
        await _loadVerificationStatus(); // Actualizar el estado
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? tr('error_uploading_selfie'))),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('error_uploading_selfie')}: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildVerificationStatusIndicator() {
    IconData icon;
    Color color;
    String status;

    if (_verificationStatus == 'true') {
      icon = Icons.verified;
      color = Colors.green;
      status = tr('verification_approved');
    } else if (_verificationStatus == 'pendiente') {
      icon = Icons.pending;
      color = Colors.orange;
      status = tr('verification_pending');
    } else {
      icon = Icons.gpp_maybe;
      color = Colors.grey;
      status = tr('account_verification');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_verificationStatus == 'pendiente')
                  Text(
                    tr('verification_in_progress'),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('verification_instructions'),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            tr('verification_benefits'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildBenefitItem(tr('verification_benefits_1')),
          _buildBenefitItem(tr('verification_benefits_3')),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentUpload() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('upload_id'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Si ya se ha subido el documento, mostrar mensaje de éxito
          if (_hasIdentityDocument)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    tr('document_uploaded'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          // Si no se ha subido el documento, mostrar instrucciones y opciones para subir
          else ...[  
            Text(
              tr('id_instructions'),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (_identityDocumentFile != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _identityDocumentFile!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ElevatedButton.icon(
              icon: Icon(_identityDocumentFile == null ? Icons.upload : Icons.edit),
              label: Text(_identityDocumentFile == null ? tr('upload_id') : tr('change_document')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _showImageSourceActionSheet(true),
            ),
            if (_identityDocumentFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(
                  onPressed: _uploadIdentityDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(tr('submit')),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelfieUpload() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('upload_selfie'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Si ya se ha subido el selfie, mostrar mensaje de éxito
          if (_hasSelfie)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    tr('selfie_uploaded'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          // Si no se ha subido el selfie, mostrar instrucciones y opciones para subir
          else ...[  
            Text(
              tr('selfie_instructions'),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (_selfieFile != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selfieFile!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ElevatedButton.icon(
              icon: Icon(_selfieFile == null ? Icons.upload : Icons.edit),
              label: Text(_selfieFile == null ? tr('upload_selfie') : tr('change_selfie')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: !_hasIdentityDocument 
                  ? null // Deshabilitado si no hay documento
                  : () => _showImageSourceActionSheet(false),
            ),
            if (_selfieFile != null && _hasIdentityDocument)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(
                  onPressed: _uploadSelfieWithDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(tr('verification_submit')),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('identity_verification')),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildVerificationStatusIndicator(),
                  const SizedBox(height: 16),
                  if (_verificationStatus == 'false') _buildVerificationInstructions(),
                  if (_verificationStatus == 'false') const SizedBox(height: 16),
                  // Si ya se ha subido el documento pero no el selfie, mostrar el selfie primero
                  if (_verificationStatus == 'false' && _hasIdentityDocument && !_hasSelfie) 
                    _buildSelfieUpload(),
                  if (_verificationStatus == 'false' && _hasIdentityDocument && !_hasSelfie) 
                    const SizedBox(height: 16),
                  // Siempre mostrar el documento
                  if (_verificationStatus == 'false') _buildDocumentUpload(),
                  // Si no tiene documento o ya tiene selfie, mostrar selfie después del documento
                  if (_verificationStatus == 'false' && _hasIdentityDocument && _hasSelfie)
                    const SizedBox(height: 16),
                  if (_verificationStatus == 'false' && _hasIdentityDocument && _hasSelfie)
                    _buildSelfieUpload(),
                  if (_verificationStatus == 'pendiente')
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                          const SizedBox(height: 8),
                          Text(
                            tr('verification_in_progress'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  if (_verificationStatus == 'true')
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.verified_user, color: Colors.green, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            tr('verification_complete'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
