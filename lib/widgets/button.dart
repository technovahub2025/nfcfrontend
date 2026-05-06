import 'package:flutter/material.dart';
import 'package:nfc/core/color/colors.dart';

// ignore: camel_case_types
class userButton extends StatelessWidget {
  final String text;
 
  const userButton({
    super.key,
   required this.text
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      width: 368,
      child: ElevatedButton(onPressed: ()
      {

      },
      style: ElevatedButton.styleFrom(
        backgroundColor: button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusGeometry.circular(10)
        )
      ), child: Text(text,style: TextStyle(fontSize: 20,color: Colors.white),

      )
      ),
    );
  }
}