import 'package:flutter/material.dart';
import 'package:nfc/core/color/colors.dart';

// ignore: camel_case_types
class userTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final bool obscureText;
  final bool isPassword;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int? maxLines;
  final VoidCallback? onTap;

  const userTextField({
    super.key,
    required this.hint,
    required this.label,
    required this.controller,
    required this.icon,
    this.obscureText = false,
    this.isPassword = false,
    this.validator,
    this.keyboardType,
    this.maxLines,
    this.onTap,
  });

  @override
  State<userTextField> createState() => _userTextFieldState();
}

// ignore: camel_case_types
class _userTextFieldState extends State<userTextField> {
  bool _obscureText = false;

  @override
  void initState() {
    super.initState();
    // Treat `isPassword` as an implicit request to start obscured.
    _obscureText = widget.obscureText || widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final bool showPasswordToggle = widget.isPassword || widget.obscureText;
    return SizedBox(
      height: 58,
      width: 368,
      child: TextFormField(
        controller: widget.controller,
        obscureText: _obscureText,
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        maxLines: showPasswordToggle ? 1 : (widget.maxLines ?? 1),
        onTap: widget.onTap,
        decoration: InputDecoration(
          hintText: widget.hint,
          labelText: widget.label,
          filled: true,
          fillColor: textfield,
          prefixIcon: Icon(widget.icon),
          suffixIcon: showPasswordToggle
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }
}
