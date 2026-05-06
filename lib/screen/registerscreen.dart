import 'package:flutter/material.dart';
import 'package:nfc/screen/loginscreen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void register() {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage("Please fill all fields");
      return;
    }

    if (!email.contains("@")) {
      showMessage("Enter valid email");
      return;
    }

    if (password.length < 6) {
      showMessage("Password must be 6+ characters");
      return;
    }

    // TODO: Connect backend API
    print("Register with $email / $password");

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Register",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

            const SizedBox(height: 30),

            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

           SizedBox(
  width: double.infinity, // full width
  height: 50, // button height
  child: ElevatedButton(
    onPressed: register,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue, // blue color
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5), // small or 0 for sharp rectangle
      ),
    ),
    child: const Text(
      "Register",
      style: TextStyle(fontSize: 16, color: Colors.white),
    ),
  ),
),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text("Already have account? Login"),
            ),
          ],
        ),
      ),
    );
  }
}