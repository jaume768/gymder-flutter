import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'terms_conditions_screen.dart';
import 'privacy_policy_screen.dart';

class AcercaDeScreen extends StatefulWidget {
  const AcercaDeScreen({Key? key}) : super(key: key);

  @override
  State<AcercaDeScreen> createState() => _AcercaDeScreenState();
}

class _AcercaDeScreenState extends State<AcercaDeScreen> {
  String appVersion = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        appVersion = 'No disponible';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("about"), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color.fromRGBO(20, 20, 20, 1.0),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[800],
                        image: const DecorationImage(
                          image: AssetImage('assets/images/logo.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'GYMswipe',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      tr("version"),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildSection(tr("app_description"), tr("app_description_text")),
                  const SizedBox(height: 20),
                  _buildSectionTitle(tr("legal_information")),
                  _buildClickableItem(
                    tr("terms_conditions"),
                    Icons.gavel,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TermsConditionsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildClickableItem(
                    tr("privacy_policy"),
                    Icons.privacy_tip,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle(tr("contact_us")),
                  _buildClickableItem(
                    'contact@gymswipe.app',
                    Icons.email,
                    () {
                      _launchEmail('contact@gymswipe.app');
                    },
                  ),
                  _buildClickableItem(
                    tr("visit_website"),
                    Icons.language,
                    () {
                      _launchURL('https://gymswipe.app');
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle(tr("social_media")),
                  _buildClickableItem(
                    'Instagram',
                    Icons.camera_alt,
                    () {
                      _launchURL('https://instagram.com/gymswipe');
                    },
                  ),
                  _buildClickableItem(
                    'TikTok',
                    Icons.chat,
                    () => _launchURL('https://tiktok.com/gymswipe'),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: Text(
                      '© ${DateTime.now().year} GYMswipe - ' + tr("all_rights_reserved"),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
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
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildClickableItem(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueAccent, size: 24),
            const SizedBox(width: 16),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("cannot_open_url"))),
      );
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri uri = Uri.parse('mailto:$email');
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("cannot_open_email"))),
      );
    }
  }
}
