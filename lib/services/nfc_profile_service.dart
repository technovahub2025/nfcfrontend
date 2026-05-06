import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NFCProfileService {
  static const String baseUrl = 'https://nfcprofilebackend.onrender.com/api';

  // Show request in alert
  static void showRequestAlert(BuildContext context, String method, Map<String, dynamic> requestBody) {
    try {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('API Request - $method'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('URL: $baseUrl/$method', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text('Request Body:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    const JsonEncoder.withIndent('  ').convert(requestBody),
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error showing request alert: $e');
      // Fallback: show simple snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error displaying request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show response in alert
  static void showResponseAlert(BuildContext context, String method, int statusCode, String responseBody) {
    try {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('API Response - $method'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Status Code: $statusCode', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text('Response Body:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusCode == 200 ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    responseBody.length > 1000 
                      ? '${responseBody.substring(0, 1000)}...\n\n[Response truncated - too long to display]'
                      : responseBody,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error showing response alert: $e');
      // Fallback: show simple snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error displaying response: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Create a new profile
  static Future<Map<String, dynamic>?> createProfile({
    required String name,
    String? phone,
    String? email,
    String? address,
    BuildContext ? context,
    String? bio,
    Map<String, String>? social,
    String? profileImageBase64,

    
   final String ? googleBusiness,
  final String ?instagram,
  final String ?linkedin,
  final String ?facebook,
  }) async {
    try {
      final requestBody = {
        'name': name,
        'phone': phone ?? '',
        'email': email ?? '',
        'address': address ?? '',
        'bio': bio ?? '',
        'googleBusiness': googleBusiness ?? '',
        'instagram': instagram ?? '',
        'linkedin': linkedin ?? '',
        'facebook': facebook ?? '',
        'profileImageBase64': profileImageBase64,
      };

      // Show request alert if context is provided
      if (context != null) {
        showRequestAlert(context, 'create', requestBody);
      }

      print('DEBUG: Sending request to: $baseUrl/create');
      print('DEBUG: Request body: ${jsonEncode(requestBody)}');
      
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/create'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'Flutter-NFC-App',
            'Connection': 'keep-alive',
          },
          body: jsonEncode(requestBody),
        );

        print('DEBUG: Response status code: ${response.statusCode}');
        print('DEBUG: Response body: ${response.body}');
        print('DEBUG: Response headers: ${response.headers}');

        // Show response alert if context is provided
        if (context != null) {
          showResponseAlert(context, 'create', response.statusCode, response.body);
        }

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          print('DEBUG: Parsed response data: $responseData');
          return responseData['data'];
        } else {
          print('ERROR: Creating profile failed - Status: ${response.statusCode}');
          print('ERROR: Response body: ${response.body}');
          return null;
        }
      } on SocketException {
        print('ERROR: No internet connection or server not reachable');
        if (context != null) {
          showResponseAlert(context, 'create', 0, 'No internet connection or server not reachable');
        }
        return null;
      }
    } catch (e) {
      print('Exception creating profile: $e');
      return null;
    }
  }

  // Get profile by ID
  static Future<Map<String, dynamic>?> getProfile(String profileId,BuildContext context) async {
    try {
      final url = '$baseUrl/getprofile/$profileId';
      
      // Show request alert
      showRequestAlert(context, 'getprofile/$profileId', {});

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Flutter-NFC-App',
          'Connection': 'keep-alive',
        },
      );

      // Show response alert
      showResponseAlert(context, 'getprofile/$profileId', response.statusCode, response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(response.body);
          return responseData['data'];
        } else {
          print('Error getting profile: ${response.statusCode} - ${response.body}');
          return null;
        }
    } catch (e) {
      print('Exception getting profile: $e');
      return null;
    }
  }

  // Update existing profile
  static Future<Map<String, dynamic>?> updateProfile({
    required String profileId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? bio,
    
   final String ? googleBusiness,
  final String ?instagram,
  final String ?linkedin,
  final String ?facebook,
    String? profileImageBase64,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/update/$profileId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Flutter-NFC-App',
          'Connection': 'keep-alive',
        },
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'email': email,
          'address': address,
          'bio': bio,
          'googleBusiness': googleBusiness ?? '',
          'instagram': instagram ?? '',
          'linkedin': linkedin ?? '',
          'facebook': facebook ?? '',
          'profileImageBase64': profileImageBase64,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['data'];
      } else {
        print('Error updating profile: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception updating profile: $e');
      return null;
    }
  }

  // Delete profile
  static Future<bool> deleteProfile(String profileId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/delete/$profileId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Flutter-NFC-App',
          'Connection': 'keep-alive',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        if (kDebugMode) {
          print('Error deleting profile: ${response.statusCode} - ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception deleting profile: $e');
      }
      return false;
    }
  }

  // Generate QR code URL for profile
  static String generateProfileQRUrl(String profileId) {
    return 'https://nfcprofilebackend.onrender.com/api/getprofile/$profileId';
  }

  // Extract profile ID from QR URL
  static String? extractProfileIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('nfcprofilebackend.onrender.com')) {
        final segments = uri.pathSegments;
        if (segments.length >= 3 && segments[0] == 'api' && segments[1] == 'getprofile') {
          return segments[2];
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error extracting profile ID: $e');
      }
      return null;
    }
  }
}
