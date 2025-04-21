import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("privacy_policy"), style: const TextStyle(color: Colors.white)),
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
              tr("privacy_title"),
              style: const TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            _buildSection(tr("privacy_intro_title"), tr("privacy_intro_content")),
            _buildSection(tr("privacy_collection_title"), tr("privacy_collection_content")),
            _buildSection(tr("privacy_usage_title"), tr("privacy_usage_content")),
            _buildSection(tr("privacy_sharing_title"), tr("privacy_sharing_content")),
            _buildSection(tr("privacy_security_title"), tr("privacy_security_content")),
            _buildSection(tr("privacy_retention_title"), tr("privacy_retention_content")),
            _buildSection(tr("privacy_rights_title"), tr("privacy_rights_content")),
            _buildSection(tr("privacy_children_title"), tr("privacy_children_content")),
            _buildSection(tr("privacy_international_title"), tr("privacy_international_content")),
            _buildSection(tr("privacy_changes_title"), tr("privacy_changes_content")),
            _buildSection(tr("privacy_contact_title"), tr("privacy_contact_content")),
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
