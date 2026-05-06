import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class BusinessDetailsPage extends StatefulWidget {
  const BusinessDetailsPage({super.key});

  @override
  State<BusinessDetailsPage> createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _designationController = TextEditingController();
  final _addressController = TextEditingController();
  final _websiteController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _twitterController = TextEditingController();
  final _googleBusinessController = TextEditingController();

  static const String _instagramBaseUrl = 'https://instagram.com/';
  static const String _linkedinBaseUrl = 'https://linkedin.com/in/';
  static const String _facebookBaseUrl = 'https://facebook.com/';
  static const String _twitterBaseUrl = 'https://x.com/';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _designationController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _linkedinController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _twitterController.dispose();
    _googleBusinessController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final result = _buildResultData();

    Navigator.pop(context, result);
  }

  Map<String, dynamic> _buildResultData() {
    return <String, dynamic>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'company': _companyController.text.trim(),
      'designation': _designationController.text.trim(),
      'address': _addressController.text.trim(),
      'website': _websiteController.text.trim(),
      'linkedin': _formatSocialUrl(
        _linkedinController.text,
        _linkedinBaseUrl,
      ),
      'instagram': _formatSocialUrl(
        _instagramController.text,
        _instagramBaseUrl,
      ),
      'facebook': _formatSocialUrl(
        _facebookController.text,
        _facebookBaseUrl,
      ),
      'twitter': _formatSocialUrl(
        _twitterController.text,
        _twitterBaseUrl,
      ),
      'googleBusiness': _googleBusinessController.text.trim(),
      'type': 'MANUAL',
      'bio': '',
    };
  }

  String _formatSocialUrl(String value, String baseUrl) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final username = trimmed.replaceAll('@', '');
    return '$baseUrl$username';
  }

  Future<void> _shareProfileAsQrCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final profileData = _buildResultData();
      final String qrData = jsonEncode(profileData);
      final QrPainter qrPainter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: false,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      final ByteData? byteData = await qrPainter.toImageData(
        1024,
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        _showShareMessage('Failed to create QR code', isError: true);
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final Directory directory = await getTemporaryDirectory();
      final String name = (_nameController.text.trim().isEmpty)
          ? 'profile'
          : _nameController.text.trim();
      final String safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final File qrFile = File('${directory.path}/$safeName-qr.png');
      await qrFile.writeAsBytes(pngBytes, flush: true);

      await Share.shareXFiles(
        [XFile(qrFile.path)],
        text: 'Scan this QR to view ${profileData['name'] ?? 'my'} profile',
        subject: '${profileData['name'] ?? 'Profile'} QR Code',
      );
    } catch (_) {
      _showShareMessage('Unable to share QR code', isError: true);
    }
  }

  void _showShareMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Details'),
        actions: [
          IconButton(
            onPressed: _shareProfileAsQrCode,
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'Share QR',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildField(
                controller: _nameController,
                label: 'Name',
                icon: Icons.person,
                requiredField: true,
              ),
              _buildField(
                controller: _phoneController,
                label: 'Phone',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                requiredField: true,
              ),
              _buildField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              _buildField(
                controller: _companyController,
                label: 'Business Name',
                icon: Icons.business,
              ),
              _buildField(
                controller: _designationController,
                label: 'Designation',
                icon: Icons.badge,
              ),
              _buildField(
                controller: _addressController,
                label: 'Address',
                icon: Icons.location_on,
                maxLines: 2,
              ),
              _buildField(
                controller: _websiteController,
                label: 'Website',
                icon: Icons.language,
                keyboardType: TextInputType.url,
              ),
              _buildField(
                controller: _linkedinController,
                label: 'LinkedIn Username',
                icon: Icons.work,
                keyboardType: TextInputType.url,
              ),
              _buildField(
                controller: _instagramController,
                label: 'Instagram Username',
                icon: Icons.camera_alt,
                keyboardType: TextInputType.url,
              ),
              _buildField(
                controller: _facebookController,
                label: 'Facebook Username',
                icon: Icons.facebook,
                keyboardType: TextInputType.url,
              ),
              _buildField(
                controller: _twitterController,
                label: 'Twitter/X Username',
                icon: Icons.alternate_email,
                keyboardType: TextInputType.url,
              ),
              _buildField(
                controller: _googleBusinessController,
                label: 'Google Business Link',
                icon: Icons.store,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool requiredField = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: (value) {
          if (requiredField && (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
