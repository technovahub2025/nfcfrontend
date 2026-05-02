import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nfc/core/color/colors.dart';
import 'package:nfc/screen/dahboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ColorScreen extends StatefulWidget {
  const ColorScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ColorScreenState createState() => _ColorScreenState();
}

class _ColorScreenState extends State<ColorScreen> {

  @override
  void initState() {
    super.initState();
    
    // Check for existing user session
    _checkUserSession();
  }

  Future<void> _checkUserSession() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Check if user is logged in
      String? userEmail = prefs.getString('user_email');
      
      bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      
      // Wait for splash duration
      await Future.delayed(Duration(seconds: 3));
      
      if (mounted) {
        if (isLoggedIn && userEmail != null) {
         
        } else {
          // New user - navigate to login
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => TopContainerExample()),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking user session: $e');
      }
      // If there's an error, default to login screen
      if (mounted) {
        await Future.delayed(Duration(seconds: 3));
        Navigator.pushReplacement(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(builder: (context) =>TopContainerExample()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              splash1,
              splash2,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/nfcsplash.png')
          ],
        ),
      ),
    );
  }
}