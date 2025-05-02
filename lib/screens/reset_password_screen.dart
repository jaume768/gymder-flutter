// lib/screens/reset_password_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/user_service.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({Key? key, required this.email}) : super(key: key);
  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  String code = '', newPassword = '';
  bool isLoading = false;
  String errorMessage = '';

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = await auth.getToken() ?? '';
      final service = UserService(token: token);
      final res =
          await service.confirmPasswordReset(widget.email, code, newPassword);
      setState(() => isLoading = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('password_reset_success'))));
        Navigator.popUntil(context, (r) => r.isFirst);
      } else {
        setState(() => errorMessage = res['message'] ?? tr('error'));
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = tr('error_resetting_password');
      });
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text('reset_password'.tr())),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                tr('enter_code_and_new_password', args: [widget.email]),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      decoration:
                          InputDecoration(labelText: 'verification_code'.tr()),
                      validator: (v) =>
                          (v?.isEmpty ?? true) ? tr('please_enter_code') : null,
                      onSaved: (v) => code = v!.trim(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration:
                          InputDecoration(labelText: 'new_password'.tr()),
                      obscureText: true,
                      validator: (v) {
                        if ((v?.length ?? 0) < 6)
                          return tr('password_min_length');
                        return null;
                      },
                      onSaved: (v) => newPassword = v!,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (errorMessage.isNotEmpty)
                Text(errorMessage, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: isLoading ? null : _resetPassword,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : Text('reset_password'.tr()),
              ),
            ],
          ),
        ),
      );
}
