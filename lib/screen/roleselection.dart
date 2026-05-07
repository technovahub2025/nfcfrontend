import 'package:flutter/material.dart';
import 'package:nfc/screen/loginscreen.dart';
import 'package:nfc/screen/userscreen.dart';
import 'package:url_launcher/url_launcher.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Role Selection"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
          child: Column(
            children: [
              const Spacer(),

              const Text(
                "Select Your Role",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 40),

              // USER BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const userEnhancedNFCScanner(),
                      ),
                    );
                  },
                  child: const Text(
                    "User",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ADMIN BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    "Admin",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),

      // FOOTER LINK
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () async {
              final Uri uri = Uri.parse('https://technovahub.in/');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '@ powered by Technovahub',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}