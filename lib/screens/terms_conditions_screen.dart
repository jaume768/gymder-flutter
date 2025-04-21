import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("terms_conditions"), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr("terms_title"),
              style: const TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            _buildSection(tr("terms_intro_title"), tr("terms_intro_content")),
            _buildSection(tr("terms_eligibility_title"), tr("terms_eligibility_content")),
            _buildSection(tr("terms_account_title"), tr("terms_account_content")),
            _buildSection(tr("terms_acceptable_use_title"), tr("terms_acceptable_use_content")),
            _buildSection(tr("terms_user_content_title"), tr("terms_user_content_content")),
            _buildSection(tr("terms_plans_title"), tr("terms_plans_content")),
            _buildSection(tr("terms_liability_title"), tr("terms_liability_content")),
            _buildSection(tr("terms_termination_title"), tr("terms_termination_content")),
            _buildSection(tr("terms_privacy_title"), tr("terms_privacy_content")),
            _buildSection(tr("terms_modifications_title"), tr("terms_modifications_content")),
            _buildSection(tr("terms_law_title"), tr("terms_law_content")),
            _buildSection(tr("terms_contact_title"), tr("terms_contact_content")),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 16.0,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
