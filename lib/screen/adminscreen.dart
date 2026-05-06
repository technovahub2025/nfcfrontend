import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide Email, Phone;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';

class adminEnhancedNFCScanner extends StatefulWidget {
  final String? writeData;
  final Function(Map<String, dynamic>)? onDataScanned;

  const adminEnhancedNFCScanner({
    super.key,
    this.writeData,
    this.onDataScanned,
  });

  @override
  State<adminEnhancedNFCScanner> createState() => _EnhancedNFCScannerState();
}

class _EnhancedNFCScannerState extends State<adminEnhancedNFCScanner> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  final _googleBusinessController = TextEditingController();
  final _instagramController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _facebookController = TextEditingController();

  // QR Code data
  String? _qrData;

  // Base URLs for social media platforms
  static const String googleBusinessBase = 'https://www.google.com/maps/search/?api=1&query=';
  static const String instagramBase = 'https://www.instagram.com/';
  static const String linkedinBase = 'https://www.linkedin.com/in/';
  static const String facebookBase = 'https://www.facebook.com/';

  String _generateGoogleBusinessURL(String businessName) {
    return businessName.isEmpty ? '' : '$googleBusinessBase${Uri.encodeComponent(businessName)}';
  }

  String _generateInstagramURL(String username) {
    return username.isEmpty ? '' : '$instagramBase$username';
  }

  String _generateLinkedInURL(String username) {
    return username.isEmpty ? '' : '$linkedinBase$username';
  }

  String _generateFacebookURL(String username) {
    return username.isEmpty ? '' : '$facebookBase$username';
  }

  Map<String, dynamic> _createProfileData() {
    return {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'address': _addressController.text.trim(),
      'bio': _bioController.text.trim(),
      'googleBusiness': _googleBusinessController.text.trim(),
      'instagram': _instagramController.text.trim(),
      'linkedin': _linkedinController.text.trim(),
      'facebook': _facebookController.text.trim(),
      'type': 'enhanced_nfc_profile',
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  bool isScanning = false;
  bool isProcessing = false;
  String currentMode = 'scan';
  bool isNFCAvailable = false;
  String? scannedData;
  String? readData;
  String? errorMessage;
  bool _isHandlingDiscoveredTag = false;

  // List to store scanned profiles
  List<Map<String, dynamic>> _savedProfiles = [];

  @override
  void initState() {
    super.initState();
    _checkNFCAvailability();
    _loadSavedProfiles();
  }

  Future<void> _loadSavedProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getStringList('saved_profiles') ?? [];
      setState(() {
        _savedProfiles = profilesJson
            .map((json) => Map<String, dynamic>.from(jsonDecode(json) as Map))
            .toList();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading profiles: $e');
      }
    }
  }

  Future<void> _saveToContacts(Map<String, dynamic> profileData) async {
    try {
      final permissionStatus = await Permission.contacts.request();
      if (!permissionStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Contacts permission denied'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      final String contactName = profileData['name']?.toString().trim() ?? 'Unknown';
      final String phoneNumber = profileData['phone']?.toString().trim() ?? '';
      final String email = profileData['email']?.toString().trim() ?? '';
      
      if (phoneNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('No phone number found to save'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final Contact newContact = Contact(
        name: Name(first: contactName),
        phones: [Phone(number: phoneNumber)],
        emails: email.isNotEmpty ? [Email(address: email)] : [],
      );

      await FlutterContacts.create(newContact);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.person_add, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Saved to contacts!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Error saving contact: ${e.toString()}'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  Future<void> _saveProfile(Map<String, dynamic> profileData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingProfiles = prefs.getStringList('saved_profiles') ?? [];
      
      profileData['saved_at'] = DateTime.now().toIso8601String();
      
      existingProfiles.add(jsonEncode(profileData));
      await prefs.setStringList('saved_profiles', existingProfiles);
      
      setState(() {
        _savedProfiles.add(profileData);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Profile saved successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Error saving profile: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _checkNFCAvailability() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    setState(() {
      isNFCAvailable = isAvailable;
      if (!isAvailable) {
        errorMessage = 'NFC is not available on this device';
        isScanning = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            _stopNFCSession();
          },
        ),
        title: const Text(
          'Digital Wall NFC',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _startWriteMode(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isNFCAvailable ? Colors.green : Colors.purple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          isNFCAvailable ? 'Create Card' : 'Test Card',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildCurrentContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentContent() {
    if (currentMode == 'scan') {
      return _buildScanOnlyMode();
    } else {
      return _buildWriteForm();
    }
  }

  Color _getStatusColor() {
    if (errorMessage != null) return Colors.red;
    if (readData != null) return Colors.green;
    if (isProcessing) return Colors.orange;
    if (isScanning) return Colors.blue;
    return isNFCAvailable ? Colors.green : Colors.grey;
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _getStatusColor(),
                fontWeight: value.contains('✓') ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonStatusInfo() {
    bool buttonDisabled = !isNFCAvailable || isScanning || isProcessing;
    String buttonReason = '';
    
    if (!isNFCAvailable) {
      buttonReason = 'NFC not available';
    } else if (isScanning) {
      buttonReason = 'Currently scanning';
    } else if (isProcessing) {
      buttonReason = 'Currently processing';
    } else {
      buttonReason = 'Ready to write';
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: buttonDisabled ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: buttonDisabled ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                buttonDisabled ? Icons.block : Icons.check_circle,
                color: buttonDisabled ? Colors.red : Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Write Button Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: buttonDisabled ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusRow('Button Enabled', buttonDisabled ? 'NO' : 'YES'),
          _buildStatusRow('Reason', buttonReason),
        ],
      ),
    );
  }

  void _startScanMode() {
    setState(() {
      currentMode = 'scan';
    });
  }

  void _startWriteMode() {
    setState(() {
      currentMode = 'write';
    });
  }

  Widget _buildWriteForm() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          _buildButtonStatusInfo(),
          
          _buildSectionHeader('Personal Information', Icons.person),
          const SizedBox(height: 12),
          
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: _buildInputDecoration('Name', Icons.person),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Please enter name';
              return null;
            },
            enabled: !isScanning && !isProcessing,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: _buildInputDecoration('Phone Number', Icons.phone),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Please enter phone number';
              return null;
            },
            enabled: !isScanning && !isProcessing,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _buildInputDecoration('Email', Icons.email),
            enabled: !isScanning && !isProcessing,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _addressController,
            textInputAction: TextInputAction.next,
            decoration: _buildInputDecoration('Address', Icons.location_on),
            maxLines: 2,
            enabled: !isScanning && !isProcessing,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _bioController,
            textInputAction: TextInputAction.next,
            decoration: _buildInputDecoration('Bio / Description', Icons.description),
            maxLines: 3,
            enabled: !isScanning && !isProcessing,
          ),

          const SizedBox(height: 20),

          _buildSectionHeader('Social Media Links', Icons.share),
          const SizedBox(height: 12),

          TextFormField(
            controller: _googleBusinessController,
            textInputAction: TextInputAction.next,
            decoration: _buildInputDecoration('Google Business Name', Icons.store),
            enabled: !isScanning && !isProcessing,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _instagramController,
            textInputAction: TextInputAction.next,
            decoration: _buildInputDecoration('Instagram Username', Icons.camera_alt),
            enabled: !isScanning && !isProcessing,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _linkedinController,
            textInputAction: TextInputAction.next,
            decoration: _buildInputDecoration('LinkedIn Username', Icons.work),
            enabled: !isScanning && !isProcessing,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _facebookController,
            textInputAction: TextInputAction.done,
            decoration: _buildInputDecoration('Facebook Username', Icons.facebook),
            enabled: !isScanning && !isProcessing,
          ),

          const SizedBox(height: 20),

          // QR Code Preview
          if (_qrData != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Text(
                    'Your QR Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _qrData!,
                      version: QrVersions.auto,
                      size: 200.0,
                      gapless: false,
                      errorStateBuilder: (cxt, err) {
                        return const Center(
                          child: Text(
                            'Error generating QR code',
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan to view profile',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (isScanning || isProcessing) ? null : (isNFCAvailable ? _onSubmit : _simulateNFCWrite),
              style: ElevatedButton.styleFrom(
                backgroundColor: isNFCAvailable ? Colors.blue : Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 2,
              ),
              child: Text(
                isNFCAvailable ? 'Write to NFC Card' : 'Test Write NFC',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOnlyMode() {



    
    return Column(
      children: [
        if (_savedProfiles.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Saved Profiles (${_savedProfiles.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._savedProfiles.asMap().entries.map((entry) {
                  final index = entry.key;
                  final profile = entry.value;
                  return _buildSavedProfileCard(index, profile);
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
      
        
        const SizedBox(height: 20),
       
        
        if (readData != null) _buildScannedDataDisplay(),      
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              _stopNFCSession();
             
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text('Back to Home'),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedProfileCard(int index, Map<String, dynamic> profile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue.shade100,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (profile['phone'] != null && profile['phone'].toString().isNotEmpty)
                  Text(
                    profile['phone'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.visibility, color: Colors.blue),
            onPressed: () {
              // Profile view disabled - no navigation
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScannedDataDisplay() {
    try {
      final userData = _parseScannedUserData(readData ?? '');
      final String qrProfileData = _buildProfileDeepLink(userData);
      
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade600,
                    Colors.purple.shade600,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 60, color: Colors.blue),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Text(
                      userData['name']?.toString() ?? 'User',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    if (userData['bio'] != null && userData['bio'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          userData['bio'].toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (userData['email'] != null && userData['email'].toString().isNotEmpty)
                    _buildDigitalWallContactItem(
                      icon: Icons.email,
                      label: userData['email'].toString(),
                      onTap: () => _launchURL('mailto:${userData['email']}'),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  if (userData['phone'] != null && userData['phone'].toString().isNotEmpty)
                    _buildDigitalWallContactItem(
                      icon: Icons.phone,
                      label: userData['phone'].toString(),
                      onTap: () => _launchURL('tel:${userData['phone']}'),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  if (_hasSocialMediaLinks(userData)) ...[
                    const Text(
                      'Connect With Me',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (userData['instagram'] != null && userData['instagram'].toString().isNotEmpty)
                          _buildDigitalWallSocialChip(
                            icon: Icons.camera_alt,
                            label: 'Instagram',
                            url: userData['instagram'],
                            color: Colors.purple,
                          ),
                        if (userData['linkedin'] != null && userData['linkedin'].toString().isNotEmpty)
                          _buildDigitalWallSocialChip(
                            icon: Icons.work,
                            label: 'LinkedIn',
                            url: userData['linkedin'],
                            color: Colors.blue,
                          ),
                        if (userData['facebook'] != null && userData['facebook'].toString().isNotEmpty)
                          _buildDigitalWallSocialChip(
                            icon: Icons.facebook,
                            label: 'Facebook',
                            url: userData['facebook'],
                            color: Colors.blue.shade800,
                          ),
                        if (userData['googleBusiness'] != null && userData['googleBusiness'].toString().isNotEmpty)
                          _buildDigitalWallSocialChip(
                            icon: Icons.store,
                            label: 'Google Business',
                            url: userData['googleBusiness'],
                            color: Colors.red,
                          ),
                        if (userData['twitter'] != null && userData['twitter'].toString().isNotEmpty)
                          _buildDigitalWallSocialChip(
                            icon: Icons.alternate_email,
                            label: 'Twitter/X',
                            url: userData['twitter'],
                            color: Colors.black87,
                          ),
                       
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // QR Code Section for scanned profile
                  if (userData.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'QR Code',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                QrImageView(
                                  data: qrProfileData,
                                  version: QrVersions.auto,
                                  size: 150.0,
                                  gapless: false,
                                  errorStateBuilder: (cxt, err) {
                                    return const Center(
                                      child: Text(
                                        'Error generating QR code',
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Scan to open this profile',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text('Error displaying data: $e'),
      );
    }
  }

  Widget _buildDigitalWallContactItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.blue.shade600,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDigitalWallSocialChip({
    required IconData icon,
    required String label,
    required String url,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchURL(url, platform: _platformFromLabel(label)),
          borderRadius: BorderRadius.circular(25),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasSocialMediaLinks(Map<String, dynamic> data) {
    return (data['googleBusiness'] != null && data['googleBusiness'].toString().isNotEmpty) ||
           (data['instagram'] != null && data['instagram'].toString().isNotEmpty) ||
           (data['linkedin'] != null && data['linkedin'].toString().isNotEmpty) ||
           (data['facebook'] != null && data['facebook'].toString().isNotEmpty) ||
           (data['twitter'] != null && data['twitter'].toString().isNotEmpty);
  }

  void _launchURL(String url, {String? platform}) async {
    final Uri uri = _buildSocialUri(url, platform: platform);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Uri _buildSocialUri(String value, {String? platform}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return Uri.parse('https://example.com');
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('mailto:') || trimmed.startsWith('tel:')) {
      return Uri.parse(trimmed);
    }
    switch (platform) {
      case 'instagram':
        return Uri.parse('https://www.instagram.com/${trimmed.replaceAll('@', '')}');
      case 'linkedin':
        return Uri.parse('https://www.linkedin.com/in/${trimmed.replaceAll('@', '')}');
      case 'facebook':
        return Uri.parse('https://www.facebook.com/${trimmed.replaceAll('@', '')}');
      case 'googleBusiness':
        return Uri.parse('https://www.google.com/search/?api=1&query=${Uri.encodeComponent(trimmed)}');
      case 'twitter':
        return Uri.parse('https://x.com/${trimmed.replaceAll('@', '')}');
      default:
        break;
    }
    if (trimmed.startsWith('@')) {
      return Uri.parse('https://x.com/${trimmed.replaceAll('@', '')}');
    }
    return Uri.parse('https://$trimmed');
  }

  String _platformFromLabel(String label) {
    switch (label) {
      case 'Instagram':
        return 'instagram';
      case 'LinkedIn':
        return 'linkedin';
      case 'Facebook':
        return 'facebook';
      case 'Google Business':
        return 'googleBusiness';
      case 'Twitter/X':
        return 'twitter';
      default:
        return '';
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  String _decodeTextRecordPayload(Uint8List payload) {
    if (payload.isEmpty) return '';
    
    // Safe bounds checking
    if (payload.length < 2) {
      return utf8.decode(payload, allowMalformed: true);
    }
    
    final statusByte = payload[0];
    final languageCodeLength = statusByte & 0x3F;
    
    // Safe language code length check
    if (payload.length <= languageCodeLength + 1) {
      return utf8.decode(payload, allowMalformed: true);
    }
    
    final isUtf16 = (statusByte & 0x80) != 0;
    final textBytes = payload.sublist(1 + languageCodeLength);
    
    if (textBytes.isEmpty) return '';

    if (!isUtf16) {
      return utf8.decode(textBytes, allowMalformed: true);
    }

    // Safe UTF-16 decoding
    if (textBytes.length >= 2) {
      final bom0 = textBytes[0];
      final bom1 = textBytes[1];
      
      if (bom0 == 0xFF && bom1 == 0xFE) {
        final leBytes = Uint8List.fromList(textBytes.sublist(2));
        if (leBytes.isNotEmpty) {
          final evenLen = leBytes.length - (leBytes.length % 2);
          if (evenLen > 0) {
            return String.fromCharCodes(Uint16List.view(leBytes.buffer, 0, evenLen ~/ 2));
          }
        }
      }
      
      if (bom0 == 0xFE && bom1 == 0xFF) {
        final raw = Uint8List.fromList(textBytes.sublist(2));
        if (raw.length >= 2) {
          final be = raw.length.isOdd ? raw.sublist(0, raw.length - 1) : raw;
          for (int i = 0; i + 1 < be.length; i += 2) {
            final t = be[i];
            be[i] = be[i + 1];
            be[i + 1] = t;
          }
          return String.fromCharCodes(Uint16List.view(be.buffer, 0, be.length ~/ 2));
        }
      }
    }

    // Fallback UTF-16 decoding
    if (textBytes.isNotEmpty) {
      final raw = Uint8List.fromList(textBytes);
      final be = raw.length.isOdd ? raw.sublist(0, raw.length - 1) : raw;
      if (be.isNotEmpty) {
        return String.fromCharCodes(Uint16List.view(be.buffer, 0, be.length ~/ 2));
      }
    }
    
    return '';
  }

  String _decodeNdefMessage(NdefMessage message) {
    final parts = <String>[];
    
    // Safe check for records
    final records = message.records ?? [];
    if (records.isEmpty) {
      return '(Empty NFC tag)';
    }
    
    for (final record in records) {
      // Safe type decoding
      String type = '';
      try {
        if (record.type != null) {
          type = ascii.decode(record.type!, allowInvalid: true);
        }
      } catch (_) {
        type = '';
      }
      
      // Handle text records
      if (type == 'T') {
        if (record.payload != null && record.payload!.isNotEmpty) {
          parts.add(_decodeTextRecordPayload(record.payload!));
        }
        continue;
      }
      
      // Handle other records
      if (record.payload != null && record.payload!.isNotEmpty) {
        try {
          parts.add(utf8.decode(record.payload!, allowMalformed: true));
        } catch (_) {
          // Skip malformed payload
        }
      }
    }
    
    return parts.where((p) => p.trim().isNotEmpty).join('\n');
  }

  Map<String, dynamic> _parseScannedUserData(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text == '(Empty tag)') {
      return {};
    }

    try {
      final uri = Uri.tryParse(text);
      if (uri != null && uri.scheme == 'nfcapp' && uri.host == 'profile') {
        final encoded = uri.queryParameters['data'];
        if (encoded != null && encoded.isNotEmpty) {
          final decodedJson = utf8.decode(base64Url.decode(encoded));
          final decoded = jsonDecode(decodedJson);
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        }
      }
    } catch (_) {}

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    final parsed = <String, dynamic>{};
    final lines = text.split('\n');
    for (final line in lines) {
      if (!line.contains(':')) continue;
      final parts = line.split(':');
      if (parts.length < 2) continue;
      final key = parts.first.trim();
      final value = parts.sublist(1).join(':').trim();
      if (key.isNotEmpty) {
        parsed[key] = value;
      }
    }

    if (parsed.isEmpty) {
      return {
        'name': 'Scanned NFC Data',
        'bio': text,
      };
    }

    return parsed;
  }

  String _buildProfileDeepLink(Map<String, dynamic> profileData) {
    final encoded = base64Url.encode(utf8.encode(jsonEncode(profileData)));
    return 'nfcapp://profile?data=$encoded';
  }

  void _onSubmit() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      isProcessing = true;
      errorMessage = null;
    });

    try {
      final profileData = _createProfileData();
      final nfcPayload = jsonEncode(profileData);
      final deepLinkPayload = _buildProfileDeepLink(profileData);
      setState(() {
        _qrData = deepLinkPayload;
      });
      await _saveProfile(profileData);
      _startNFCWriteSession(nfcPayload);
    } catch (e) {
      setState(() {
        isProcessing = false;
        errorMessage = 'Failed to save profile: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Failed to save profile: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _startNFCReadSession() async {
    if (!isNFCAvailable) return;

    setState(() {
      isScanning = true;
      isProcessing = false;
      errorMessage = null;
      readData = null;
      scannedData = null;
    });

    try {
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Now tap the NFC card to read the data')),
        );
      }

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          if (_isHandlingDiscoveredTag) return;
          _isHandlingDiscoveredTag = true;
          try {
            if (!mounted) return;
            
            setState(() {
              isProcessing = true;
            });

            final ndef = Ndef.from(tag);
            if (ndef == null) {
              try {
                await NfcManager.instance.stopSession(errorMessage: 'This NFC tag is not NDEF compatible.');
                if (!mounted) return;
                setState(() {
                  isScanning = false;
                  isProcessing = false;
                  errorMessage = 'This NFC tag is not NDEF compatible.';
                });
                _showErrorToast('NFC card is not compatible', context);
                
                // Show incompatible tag error in alert
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('NFC Tag Error'),
                      content: Text('This NFC tag is not NDEF compatible. Please use a different NFC card.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
                return;
              } catch (e) {
                print('Error stopping NFC session: $e');
                if (!mounted) return;
                setState(() {
                  isScanning = false;
                  isProcessing = false;
                  errorMessage = 'NFC session error: $e';
                });
                
                // Show session error in alert
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('NFC Session Error'),
                      content: Text('Failed to process NFC tag: $e'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
                return;
              }
            }

            try {
              NdefMessage? message = ndef.cachedMessage;
              if (message == null) {
                message = await ndef.read();
              }
              
              if (!mounted) return;
              
              final decoded = _decodeNdefMessage(message);
              if (kDebugMode) {
                print('Decoded NFC data: $decoded');
              }

              await NfcManager.instance.stopSession(alertMessage: 'Read from NFC tag');
              if (!mounted) return;
              
              setState(() {
                readData = decoded.isEmpty ? '(Empty tag)' : decoded;
                isScanning = false;
                isProcessing = false;
              });
              if (mounted) {
                _showReadResult();
              }
            } catch (e) {
              print('Error reading NFC tag: $e');
              try {
                await NfcManager.instance.stopSession(errorMessage: 'Read failed');
              } catch (stopError) {
                print('Error stopping NFC session: $stopError');
              }
              
              if (!mounted) return;
              setState(() {
                isScanning = false;
                isProcessing = false;
                errorMessage = 'Failed to read NFC data';
              });
            }
          } catch (e) {
            print('Critical NFC error: $e');
            try {
              await NfcManager.instance.stopSession();
            } catch (stopError) {
              print('Error stopping NFC session in catch: $stopError');
            }
            
            if (!mounted) return;
            setState(() {
              isScanning = false;
              isProcessing = false;
              errorMessage = 'NFC scanning error: $e';
            });
            
            // Show error in alert
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('NFC Error'),
                  content: Text('Failed to scan NFC card: $e'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('OK'),
                    ),
                  ],
                ),
              );
            }
          } finally {
            _isHandlingDiscoveredTag = false;
          }
        },
        onError: (error) async {
          print('NFC session error: $error');
          try {
            await NfcManager.instance.stopSession();
          } catch (e) {
            print('Error stopping NFC session on error: $e');
          }
          
          if (!mounted) return;
          setState(() {
            isScanning = false;
            isProcessing = false;
            errorMessage = 'NFC connection error: $error';
          });
          
          // Show NFC connection error in alert
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('NFC Connection Error'),
                content: Text('Failed to establish NFC connection: $error'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('OK'),
                  ),
                ],
              ),
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isScanning = false;
        isProcessing = false;
        errorMessage = 'Failed to start NFC session: $e';
      });
      
      // Show session start error in alert
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('NFC Session Error'),
            content: Text('Failed to start NFC scanning: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _startNFCWriteSession(String payload) async {
    if (!isNFCAvailable) return;

    setState(() {
      isScanning = true;
      isProcessing = false;
      scannedData = null;
      readData = null;
      errorMessage = null;
    });

    try {
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}

      final payloadBytes = Uint8List.fromList(utf8.encode(payload));
      final message = NdefMessage([
        NdefRecord.createText(payload),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Now tap the NFC card to write the data')),
        );
      }

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            if (!mounted) return;
            setState(() {
              isProcessing = true;
            });

            final ndef = Ndef.from(tag);
            if (ndef == null) {
              final ndefFormatable = NdefFormatable.from(tag);
              if (ndefFormatable == null) {
                await NfcManager.instance.stopSession(errorMessage: 'This NFC tag is not NDEF compatible.');
                if (!mounted) return;
                setState(() {
                  isScanning = false;
                  isProcessing = false;
                  errorMessage = 'This NFC tag is not NDEF compatible.';
                });
                return;
              }

              await ndefFormatable.format(message);
              await NfcManager.instance.stopSession(alertMessage: 'Tag formatted & written');

              if (!mounted) return;
              setState(() {
                scannedData = payload;
                isScanning = false;
                isProcessing = false;
              });

              _showWriteResult();
              return;
            }

            if (!ndef.isWritable) {
              await NfcManager.instance.stopSession(errorMessage: 'This NFC tag is read-only.');
              if (!mounted) return;
              setState(() {
                isScanning = false;
                isProcessing = false;
                errorMessage = 'This NFC tag is read-only.';
              });
             
              return;
            }

            if (payloadBytes.length > ndef.maxSize) {
              await NfcManager.instance.stopSession(errorMessage: 'Data too large for this tag.');
              if (!mounted) return;
              setState(() {
                isScanning = false;
                isProcessing = false;
                errorMessage =
                    'Data too large for this tag. Max: ${ndef.maxSize} bytes, got: ${payloadBytes.length} bytes.';
              });
            
              return;
            }

            await ndef.write(message);
            await NfcManager.instance.stopSession(alertMessage: 'Written to NFC tag');

            if (!mounted) return;
            setState(() {
              scannedData = payload;
              isScanning = false;
              isProcessing = false;
            });

            _showWriteResult();
          } catch (e) {
            await NfcManager.instance.stopSession(errorMessage: 'Write failed');
            if (!mounted) return;
            setState(() {
              isScanning = false;
              isProcessing = false;
              errorMessage = 'Failed to write card: $e';
            });
           
          }
        },
        onError: (error) async {
          await NfcManager.instance.stopSession();
          if (!mounted) return;
          setState(() {
            isScanning = false;
            isProcessing = false;
            errorMessage = 'NFC Error: $error';
          });
          
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isScanning = false;
        errorMessage = 'Failed to start NFC session: $e';
      });
    }
  }

  Future<void> _stopNFCSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (e) {}
    if (!mounted) return;
    setState(() {
      isScanning = false;
      isProcessing = false;
    });
  }

  void _showWriteResult() {
    final data = scannedData ?? '';
    if (data.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('Data submitted successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }



  void _showReadResult() {
    final userData = _parseScannedUserData(readData ?? '');

    try {
      if (userData.isNotEmpty) {
        _saveToContacts(userData);
        _openScannedDataScreen(userData);

        if (widget.onDataScanned != null) {
          widget.onDataScanned!(userData);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing NFC data: $e');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text('NFC data scanned successfully!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorToast(String message, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openScannedDataScreen(Map<String, dynamic> userData) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhancedNFCDataDisplayScreen(userData: userData),
      ),
    );
  }

  void _startQRScan() {
    final MobileScannerController qrController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        bool handled = false;
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Stack(
            children: [
              MobileScanner(
                controller: qrController,
                onDetect: (capture) async {
                  if (handled) return;
                  final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
                  final String? raw = barcode?.rawValue;
                  if (raw == null || raw.trim().isEmpty) return;
                  handled = true;

                  await qrController.stop();
                  if (!mounted) return;
                  Navigator.pop(context);

                  final Map<String, dynamic> parsedUserData = _parseScannedUserData(raw);
                  final String normalizedReadData = jsonEncode(parsedUserData);

                  setState(() {
                    readData = normalizedReadData;
                    isScanning = false;
                    isProcessing = false;
                    errorMessage = null;
                  });

                  if (parsedUserData.isNotEmpty) {
                    _saveToContacts(parsedUserData);
                    _openScannedDataScreen(parsedUserData);
                    if (widget.onDataScanned != null) {
                      widget.onDataScanned!(parsedUserData);
                    }
                  }
                },
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () async {
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              const Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Scan QR to open profile',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      qrController.dispose();
    });
  }

  void _simulateNFCSRead() {
    setState(() {
      isScanning = true;
      isProcessing = true;
      errorMessage = null;
      readData = null;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      final testUserData = {
        'name': 'Test User',
        'phone': '+1234567890',
        'email': 'test@example.com',
        'address': '123 Test Street',
        'bio': 'This is test NFC data',
        'googleBusiness': _generateGoogleBusinessURL('Test Cafe, Chennai'),
        'instagram': _generateInstagramURL('testuser_official'),
        'linkedin': _generateLinkedInURL('test-user-profile'),
        'facebook': _generateFacebookURL('test.user.page'),
        
        'type': 'NFC',
        'created_at': DateTime.now().toIso8601String(),
      };

      final deepLinkPayload = _buildProfileDeepLink(testUserData);

      setState(() {
        readData = jsonEncode(testUserData);
        _qrData = deepLinkPayload;
        isScanning = false;
        isProcessing = false;
      });
      _showReadResult();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.nfc, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('Test NFC data scanned!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  void _simulateNFCWrite() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      errorMessage = null;
      readData = null;
      isScanning = true;
      isProcessing = true;
    });

    try {
      final profileData = _createProfileData();
      final nfcPayload = jsonEncode(profileData);
      final deepLinkPayload = _buildProfileDeepLink(profileData);
      setState(() {
        _qrData = deepLinkPayload;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;

        setState(() {
          scannedData = nfcPayload;
          isScanning = false;
          isProcessing = false;
        });

        _saveProfile(profileData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Profile saved and test data submitted!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      });
    } catch (e) {
      setState(() {
        isScanning = false;
        isProcessing = false;
        errorMessage = 'Failed to save profile: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Failed to save profile: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    unawaited(NfcManager.instance.stopSession().catchError((_) {}));
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _googleBusinessController.dispose();
    _instagramController.dispose();
    _linkedinController.dispose();
    _facebookController.dispose();
    super.dispose();
  }
}

// ==================== NFC DATA DISPLAY SCREEN ====================
class EnhancedNFCDataDisplayScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const EnhancedNFCDataDisplayScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Digital Business Card',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: () => _shareProfile(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade600, Colors.purple.shade600],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 60, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userData['name'] ?? 'User',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (userData['bio'] != null && userData['bio'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        userData['bio'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildContactCard(
                    icon: Icons.phone,
                    title: 'Phone',
                    value: userData['phone'] ?? 'Not provided',
                    color: Colors.green,
                    onTap: () => _makePhoneCall(userData['phone']),
                  ),
                  const SizedBox(height: 12),
                  _buildContactCard(
                    icon: Icons.email,
                    title: 'Email',
                    value: userData['email'] ?? 'Not provided',
                    color: Colors.red,
                    onTap: () => _sendEmail(userData['email']),
                  ),
                  const SizedBox(height: 12),
                  _buildContactCard(
                    icon: Icons.location_on,
                    title: 'Address',
                    value: userData['address'] ?? 'Not provided',
                    color: Colors.orange,
                    onTap: () => _openMap(userData['address']),
                  ),
                ],
              ),
            ),

            if (_hasSocialMediaLinks(userData))
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connect With Me',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (userData['googleBusiness'] != null && userData['googleBusiness'].toString().isNotEmpty)
                          _buildSocialButton(
                            icon: Icons.store,
                            label: 'Google Business',
                            color: Colors.blue,
                            url: userData['googleBusiness'],
                          ),
                        if (userData['instagram'] != null && userData['instagram'].toString().isNotEmpty)
                          _buildSocialButton(
                            icon: Icons.camera_alt,
                            label: 'Instagram',
                            color: Colors.purple,
                            url: userData['instagram'],
                          ),
                        if (userData['linkedin'] != null && userData['linkedin'].toString().isNotEmpty)
                          _buildSocialButton(
                            icon: Icons.work,
                            label: 'LinkedIn',
                            color: Colors.blue.shade700,
                            url: userData['linkedin'],
                          ),
                        if (userData['facebook'] != null && userData['facebook'].toString().isNotEmpty)
                          _buildSocialButton(
                            icon: Icons.facebook,
                            label: 'Facebook',
                            color: Colors.blue.shade800,
                            url: userData['facebook'],
                          ),
                        if (userData['twitter'] != null && userData['twitter'].toString().isNotEmpty)
                          _buildSocialButton(
                            icon: Icons.alternate_email,
                            label: 'Twitter/X',
                            color: Colors.black87,
                            url: userData['twitter'],
                          ),
                      
                      ],
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: value != 'Not provided' ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (value != 'Not provided')
                Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required String url,
  }) {
    return ElevatedButton.icon(
      onPressed: () => _launchURL(url, platform: _platformFromLabel(label)),
      icon: Icon(icon, color: Colors.white, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  bool _hasSocialMediaLinks(Map<String, dynamic> data) {
    return (data['googleBusiness'] != null && data['googleBusiness'].toString().isNotEmpty) ||
           (data['instagram'] != null && data['instagram'].toString().isNotEmpty) ||
           (data['linkedin'] != null && data['linkedin'].toString().isNotEmpty) ||
           (data['facebook'] != null && data['facebook'].toString().isNotEmpty) ||
           (data['twitter'] != null && data['twitter'].toString().isNotEmpty);
  }

  void _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber != null && phoneNumber.isNotEmpty && phoneNumber != 'Not provided') {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    }
  }

  void _sendEmail(String? email) async {
    if (email != null && email.isNotEmpty && email != 'Not provided') {
      final Uri emailUri = Uri(scheme: 'mailto', path: email);
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      }
    }
  }

  void _openMap(String? address) async {
    if (address != null && address.isNotEmpty && address != 'Not provided') {
      final Uri mapUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
      if (await canLaunchUrl(mapUri)) {
        await launchUrl(mapUri);
      }
    }
  }

  void _launchURL(String url, {String? platform}) async {
    final Uri uri = _buildSocialUri(url, platform: platform);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Uri _buildSocialUri(String value, {String? platform}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return Uri.parse('https://example.com');
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.parse(trimmed);
    }
    switch (platform) {
      case 'instagram':
        return Uri.parse('https://www.instagram.com/${trimmed.replaceAll('@', '')}');
      case 'linkedin':
        return Uri.parse('https://www.linkedin.com/in/${trimmed.replaceAll('@', '')}');
      case 'facebook':
        return Uri.parse('https://www.facebook.com/${trimmed.replaceAll('@', '')}');
      case 'googleBusiness':
        return Uri.parse('https://www.google.com/search/?api=1&query=${Uri.encodeComponent(trimmed)}');
      case 'twitter':
        return Uri.parse('https://x.com/${trimmed.replaceAll('@', '')}');
      default:
        break;
    }
    if (trimmed.contains('instagram.com') ||
        trimmed.contains('linkedin.com') ||
        trimmed.contains('facebook.com') ||
        trimmed.contains('x.com') ||
        trimmed.contains('twitter.com')) {
      return Uri.parse('https://$trimmed');
    }
    if (trimmed.startsWith('@')) {
      return Uri.parse('https://x.com/${trimmed.replaceAll('@', '')}');
    }
    return Uri.parse('https://$trimmed');
  }

  String _platformFromLabel(String label) {
    switch (label) {
      case 'Instagram':
        return 'instagram';
      case 'LinkedIn':
        return 'linkedin';
      case 'Facebook':
        return 'facebook';
      case 'Google Business':
        return 'googleBusiness';
      case 'Twitter/X':
        return 'twitter';
      default:
        return '';
    }
  }

  void _shareProfile(BuildContext context) {
    final profileText = '''
Name: ${userData['name'] ?? 'N/A'}
Phone: ${userData['phone'] ?? 'N/A'}
Email: ${userData['email'] ?? 'N/A'}
Address: ${userData['address'] ?? 'N/A'}
Bio: ${userData['bio'] ?? 'N/A'}

Social Links:
${userData['googleBusiness'] != null ? 'Google Business: ${userData['googleBusiness']}\n' : ''}
${userData['instagram'] != null ? 'Instagram: ${userData['instagram']}\n' : ''}
${userData['linkedin'] != null ? 'LinkedIn: ${userData['linkedin']}\n' : ''}
${userData['facebook'] != null ? 'Facebook: ${userData['facebook']}\n' : ''}
${userData['twitter'] != null ? 'Twitter/X: ${userData['twitter']}\n' : ''}

    '''.trim();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Business Card',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  icon: Icons.copy,
                  label: 'Copy Text',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: profileText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile copied to clipboard!')),
                    );
                    Navigator.pop(context);
                  },
                ),
                _buildShareOption(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: () {
                    Navigator.pop(context);
                    Share.share(profileText);
                  },
                ),
                _buildShareOption(
                  icon: Icons.qr_code_2,
                  label: 'Share QR',
                  onTap: () {
                    Navigator.pop(context);
                    _shareProfileAsQrCode(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Future<void> _shareProfileAsQrCode(BuildContext context) async {
    try {
      final String qrData = jsonEncode(userData);
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
        _showSnack(context, 'Failed to create QR code', isError: true);
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final Directory directory = await getTemporaryDirectory();
      final String name = (userData['name'] ?? 'profile').toString();
      final String safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final File qrFile = File('${directory.path}/$safeName-qr.png');
      await qrFile.writeAsBytes(pngBytes, flush: true);

      await Share.shareXFiles(
        [XFile(qrFile.path)],
        text: 'Scan this QR to view ${userData['name'] ?? 'my'} profile',
        subject: '${userData['name'] ?? 'Profile'} QR Code',
      );
    } catch (_) {
      _showSnack(context, 'Unable to share QR code', isError: true);
    }
  }

  void _showSnack(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}
