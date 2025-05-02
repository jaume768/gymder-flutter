import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _code = '';
  String _newPassword = '';
  bool _codeSent = false;
  bool _loading = false;
  String _error = '';

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'forgot_password'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              if (!_loading)
                Card(
                  color: Colors.white10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (!_codeSent) ...[
                            // Paso 1: Pedir código
                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'email'.tr(),
                                labelStyle:
                                    const TextStyle(color: Colors.white54),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white54),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white),
                                ),
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? 'please_enter_email'.tr() : null,
                              onSaved: (v) => _email = v!.trim(),
                              cursorColor: Colors.white,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!_formKey.currentState!.validate())
                                    return;
                                  _formKey.currentState!.save();
                                  setState(() {
                                    _loading = true;
                                    _error = '';
                                  });
                                  final resp =
                                      await auth.requestPasswordReset(_email);
                                  setState(() {
                                    _loading = false;
                                  });
                                  if (resp['success'] == true) {
                                    setState(() => _codeSent = true);
                                  } else {
                                    setState(
                                        () => _error = resp['message'] ?? '');
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'send_code'.tr(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            // Paso 2: Confirmar código y nueva contraseña
                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'verification_code'.tr(),
                                labelStyle:
                                    const TextStyle(color: Colors.white54),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white54),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white),
                                ),
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? 'please_enter_code'.tr() : null,
                              onSaved: (v) => _code = v!.trim(),
                              cursorColor: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'new_password'.tr(),
                                labelStyle:
                                    const TextStyle(color: Colors.white54),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white54),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white),
                                ),
                              ),
                              obscureText: true,
                              validator: (v) => v!.length < 6
                                  ? 'password_min_length'.tr()
                                  : null,
                              onSaved: (v) => _newPassword = v!,
                              cursorColor: Colors.white,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!_formKey.currentState!.validate())
                                    return;
                                  _formKey.currentState!.save();
                                  setState(() {
                                    _loading = true;
                                    _error = '';
                                  });
                                  final resp = await auth.confirmPasswordReset(
                                    email: _email,
                                    code: _code,
                                    newPassword: _newPassword,
                                  );
                                  setState(() {
                                    _loading = false;
                                  });
                                  if (resp['success'] == true) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'password_reset_success'.tr(),
                                        ),
                                      ),
                                    );
                                    Navigator.pop(context);
                                  } else {
                                    setState(
                                        () => _error = resp['message'] ?? '');
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'confirm'.tr(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_error.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              _error,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
