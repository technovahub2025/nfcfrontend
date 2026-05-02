import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide Phone, Email;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart' hide PermissionStatus;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/nfc_profile_service.dart';

class NFCDataDisplayScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const NFCDataDisplayScreen({super.key, required this.userData});

  @override
  State<NFCDataDisplayScreen> createState() => _NFCDataDisplayScreenState();
}

class _NFCDataDisplayScreenState extends State<NFCDataDisplayScreen> {
  bool _isQRScanning = false;
  final MobileScannerController _qrScannerController = MobileScannerController();
  late Map<String, dynamic> _currentUserData;

  @override
  void initState() {
    super.initState();
    _currentUserData = Map<String, dynamic>.from(widget.userData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Digital Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2, color: Colors.black),
            tooltip: 'Share QR',
            onPressed: _shareProfileAsQrCode,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
            onPressed: () => _toggleQRScanner(),
          ),
        ],
      ),
      body: _isQRScanning 
          ? _buildQRScanner()
          : (_currentUserData.isEmpty || _currentUserData['name'] == null)
              ? _buildNoDataScreen(context)
              : _buildDataScreen(),
    );
  }

  Widget _buildNoDataScreen(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.offline_bolt,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 20),
          Text(
            'No Data Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 12),
          Text(
            'No NFC or QR data available to display',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          Container(
            width: 200,
            child: ElevatedButton.icon(
              onPressed: () => _toggleQRScanner(),
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: const Text('Scan QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back),
            label: Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataScreen() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: _buildDigitalWallProfile(),
    );
  }

  Widget _buildDigitalWallProfile() {
    return Container(
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
          // Profile Header with Gradient
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
                  // Profile Image with shadow effect
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
                  
                  // Name
                  Text(
                    _currentUserData['name'] ?? 'User',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  // Bio/Description
                  if (_currentUserData['bio'] != null && _currentUserData['bio'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _currentUserData['bio'],
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
          
          // QR Scanner Section (ALWAYS VISIBLE AT TOP)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Test message first
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('QR Scanner button pressed!'),
                      backgroundColor: Colors.blue,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  // Then try to open scanner
                  _toggleQRScanner();
                },
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                label: const Text('Scan QR Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          
          // Contact Information Section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Email
                if (_currentUserData['email'] != null && _currentUserData['email'].toString().isNotEmpty)
                  _buildDigitalWallContactItem(
                    icon: Icons.email,
                    label: _currentUserData['email'],
                    onTap: () => _sendEmail(_currentUserData['email']),
                  ),
                
                const SizedBox(height: 16),
                
                // Phone
                if (_currentUserData['phone'] != null && _currentUserData['phone'].toString().isNotEmpty)
                  _buildDigitalWallContactItem(
                    icon: Icons.phone,
                    label: _currentUserData['phone'],
                    onTap: () => _makePhoneCall(_currentUserData['phone']),
                  ),

                if (_currentUserData['company'] != null && _currentUserData['company'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDigitalWallContactItem(
                    icon: Icons.business,
                    label: _currentUserData['company'],
                  ),
                ],
                
                // QR Scanner Button (ALWAYS VISIBLE)
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleQRScanner(),
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    label: const Text('Scan QR Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Save to Contacts Button
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _saveToContacts(),
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    label: const Text('Save to Contacts'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Social Media Section
                if (_hasSocialMedia()) ...[
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
                      if (_currentUserData['instagram'] != null && _currentUserData['instagram'].toString().isNotEmpty)
                        _buildDigitalWallSocialChip(
                          icon: Icons.camera_alt,
                          label: 'Instagram',
                          url: _currentUserData['instagram'],
                          color: Colors.purple,
                        ),
                      if (_currentUserData['linkedin'] != null && _currentUserData['linkedin'].toString().isNotEmpty)
                        _buildDigitalWallSocialChip(
                          icon: Icons.work,
                          label: 'LinkedIn',
                          url: _currentUserData['linkedin'],
                          color: Colors.blue,
                        ),
                      if (_currentUserData['facebook'] != null && _currentUserData['facebook'].toString().isNotEmpty)
                        _buildDigitalWallSocialChip(
                          icon: Icons.facebook,
                          label: 'Facebook',
                          url: _currentUserData['facebook'],
                          color: Colors.blue.shade800,
                        ),
                      if (_currentUserData['googleBusiness'] != null && _currentUserData['googleBusiness'].toString().isNotEmpty)
                        _buildDigitalWallSocialChip(
                          icon: Icons.store,
                          label: 'Google Business',
                          url: _currentUserData['googleBusiness'],
                          color: Colors.red,
                        ),
                      if (_currentUserData['twitter'] != null && _currentUserData['twitter'].toString().isNotEmpty)
                        _buildDigitalWallSocialChip(
                          icon: Icons.alternate_email,
                          label: 'Twitter/X',
                          url: _currentUserData['twitter'],
                          color: Colors.black87,
                        ),
                      if (_currentUserData['website'] != null && _currentUserData['website'].toString().isNotEmpty)
                        _buildDigitalWallSocialChip(
                          icon: Icons.language,
                          label: 'Website',
                          url: _currentUserData['website'],
                          color: Colors.teal,
                        ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // QR Code Section
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
                            // QR Code Image (from assets)
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/qrcode.png',
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
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
  }










  // FIXED: Updated _buildSocialMediaButton - now builds URL internally




  bool _hasSocialMedia() {
    return (_currentUserData['instagram'] != null && _currentUserData['instagram'].toString().isNotEmpty) ||
           (_currentUserData['facebook'] != null && _currentUserData['facebook'].toString().isNotEmpty) ||
           (_currentUserData['twitter'] != null && _currentUserData['twitter'].toString().isNotEmpty) ||
           (_currentUserData['linkedin'] != null && _currentUserData['linkedin'].toString().isNotEmpty) ||
           (_currentUserData['googleBusiness'] != null && _currentUserData['googleBusiness'].toString().isNotEmpty) ||
           (_currentUserData['website'] != null && _currentUserData['website'].toString().isNotEmpty);
  }

  // Action Methods - FIXED with better error handling
  Future<void> _launchURL(String url, {String? platform}) async {
    if (kDebugMode) {
      print('Attempting to launch: $url');
    }
    
    try {
      final uri = _buildSocialUri(url, platform: platform);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        _showErrorSnackBar('Could not launch $url');
      }
    } catch (e) {
      _showErrorSnackBar('Error launching URL: $e');
      if (kDebugMode) print('Launch error: $e');
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
      case 'twitter':
        return Uri.parse('https://x.com/${trimmed.replaceAll('@', '')}');
      case 'googleBusiness':
        return Uri.parse('https://www.google.com/search/?api=1&query=${Uri.encodeComponent(trimmed)}');
      case 'website':
        return Uri.parse('https://$trimmed');
      default:
        return Uri.parse('https://$trimmed');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final uri = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showErrorSnackBar('Could not make phone call');
      }
    } catch (e) {
      _showErrorSnackBar('Error making phone call: $e');
    }
  }

  Future<void> _sendEmail(String email) async {
    try {
      final uri = Uri.parse('mailto:$email');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showErrorSnackBar('Could not send email');
      }
    } catch (e) {
      _showErrorSnackBar('Error sending email: $e');
    }
  }

  // QR Scanner Methods
  Widget _buildQRScanner() {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // QR Scanner Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => _toggleQRScanner(),
                ),
                const Expanded(
                  child: Text(
                    'Scan QR Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // Balance the close button
              ],
            ),
          ),
          
          // QR Scanner View
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  controller: _qrScannerController,
                  onDetect: (capture) {
                    if (kDebugMode) {
                      print('MobileScanner detected something: ${capture.barcodes.length} barcodes');
                    }
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (kDebugMode) {
                        print('Barcode found: ${barcode.rawValue}');
                      }
                      if (barcode.rawValue != null) {
                        _handleQRCode(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                ),
              ),
            ),
          ),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Text(
              'Position QR code in frame to scan',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleQRScanner() async {
    if (kDebugMode) {
      print('QR Scanner toggle called');
    }
    
    // Request camera permission first
    final permission = await Permission.camera.request();
    if (kDebugMode) {
      print('Camera permission: ${permission.isGranted}');
    }
    
    if (!permission.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Camera permission is required to scan QR codes'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isQRScanning = !_isQRScanning;
    });
    
    if (_isQRScanning) {
      if (kDebugMode) {
        print('Starting QR scanner');
      }
      // Start QR scanner
      _qrScannerController.start();
    } else {
      if (kDebugMode) {
        print('Stopping QR scanner');
      }
      // Stop QR scanner
      _qrScannerController.stop();
    }
  }

  void _handleQRCode(String qrData) async {
    if (kDebugMode) {
      print('QR Code detected: $qrData');
    }
    
    // Stop QR scanner
    setState(() {
      _isQRScanning = false;
    });
    _qrScannerController.stop();

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            SizedBox(width: 16),
            Text('Processing QR code...'),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 10),
      ),
    );

    try {
      // Check if QR data contains profile URL
      final profileId = NFCProfileService.extractProfileIdFromUrl(qrData);
      
      Map<String, dynamic> userData = {};
      
      if (profileId != null) {
        // Fetch profile from API
        final profileData = await NFCProfileService.getProfile(profileId,context);
        if (profileData != null) {
          userData = {
            ...profileData,
            'type': 'NFC_PROFILE',
            'profileId': profileId,
          };
          
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.person, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Profile loaded successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Profile not found
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Profile not found'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      } else {
        // Try to parse as JSON
        try {
          final Map<String, dynamic> qrContent = jsonDecode(qrData);
          userData = {
            ...qrContent,
            'type': 'QR',
          };
        } catch (e) {
          // If not JSON, create simple data
          userData = {
            'qr_data': qrData,
            'type': 'QR',
            'name': 'QR Scanned Data',
            'bio': qrData,
            'email': '',
            'phone': '',
            'company': '',
            'address': '',
            'website': '',
            'linkedin': '',
            'instagram': '',
            'facebook': '',
            'twitter': '',
          };
        }
      }
      
      if (kDebugMode) {
        print('Final user data: $userData');
      }
      
      // Update the current user data with QR/Profile data
      setState(() {
        _currentUserData.clear();
        _currentUserData.addAll(userData);
      });
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('QR code scanned and displayed!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('QR Content not JSON, creating simple data. Error: $e');
      }
      // If not JSON, create a simple map
      final Map<String, dynamic> simpleData = {
        'qr_data': qrData,
        'type': 'QR',
        'name': 'QR Scanned Data',
        'bio': qrData,
      };
      
      setState(() {
        _currentUserData.clear();
        _currentUserData.addAll(simpleData);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('QR code scanned and displayed!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
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
    final String platform = _platformFromLabel(label);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchURL(url, platform: platform),
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
      case 'Website':
        return 'website';
      default:
        return '';
    }
  }

  Future<void> _saveToContacts() async {
    try {
      final hasPermission = await FlutterContacts.permissions.has(
        PermissionType.readWrite,
      ) ||
          (await FlutterContacts.permissions.request(PermissionType.readWrite) ==
              PermissionStatus.granted);
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Contact permission is required to save contacts'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Get name and phone from user data
      final String contactName = _currentUserData['name'] ?? 'Unknown Contact';
      final String phoneNumber = _currentUserData['phone'] ?? '';
      final String email = _currentUserData['email'] ?? '';
      final String company = _currentUserData['company'] ?? '';
      final String designation = _currentUserData['designation'] ?? '';
      final String website = _currentUserData['website'] ?? '';
      final String address = _currentUserData['address'] ?? '';

      final phones = <Phone>[];
      if (phoneNumber.isNotEmpty) {
        phones.add(Phone(number: phoneNumber));
      }

      final emails = <Email>[];
      if (email.isNotEmpty) {
        emails.add(Email(address: email));
      }

      final organizations = <Organization>[];
      if (company.isNotEmpty) {
        organizations.add(
          Organization(
            name: company,
            jobTitle: designation,
          ),
        );
      }

      final notes = <String>[
        if (website.isNotEmpty) 'Website: $website',
        if (address.isNotEmpty) 'Address: $address',
        if ((_currentUserData['linkedin'] ?? '').toString().isNotEmpty) 'LinkedIn: ${_currentUserData['linkedin']}',
        if ((_currentUserData['instagram'] ?? '').toString().isNotEmpty) 'Instagram: ${_currentUserData['instagram']}',
        if ((_currentUserData['facebook'] ?? '').toString().isNotEmpty) 'Facebook: ${_currentUserData['facebook']}',
        if ((_currentUserData['twitter'] ?? '').toString().isNotEmpty) 'Twitter/X: ${_currentUserData['twitter']}',
        if ((_currentUserData['googleBusiness'] ?? '').toString().isNotEmpty) 'Google Business: ${_currentUserData['googleBusiness']}',
      ];
      final contactNotes =
          notes.isNotEmpty ? [Note(note: notes.join('\n'))] : const <Note>[];

      final Contact newContact = Contact(
        name: Name(first: contactName),
        phones: phones,
        emails: emails,
        organizations: organizations,
        notes: contactNotes,
      );

      // Save to device contacts
      await FlutterContacts.create(newContact);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('$contactName saved to contacts!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving contact: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Failed to save contact: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _qrScannerController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (kDebugMode) {
      print('Error: $message');
    }
  }

  Future<void> _shareProfileAsQrCode() async {
    if (_currentUserData.isEmpty) {
      _showShareMessage('No profile data available to share', isError: true);
      return;
    }

    try {
      final String qrData = jsonEncode(_currentUserData);
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
      final String name = (_currentUserData['name'] ?? 'profile').toString();
      final String safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final File qrFile = File('${directory.path}/$safeName-qr.png');
      await qrFile.writeAsBytes(pngBytes, flush: true);

      await Share.shareXFiles(
        [XFile(qrFile.path)],
        text: 'Scan this QR to view ${_currentUserData['name'] ?? 'my'} profile',
        subject: '${_currentUserData['name'] ?? 'Profile'} QR Code',
      );
    } catch (e) {
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
}
