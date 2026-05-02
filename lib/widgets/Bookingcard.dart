

import 'package:flutter/material.dart';

class Bookingcard  extends StatelessWidget{


  final Icon icon;


  const Bookingcard({super.key, 

    required this.icon
  });


  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      width: 105,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusGeometry.circular(20),

        ),
        color: Colors.blue,
        child: Column(

          children: [

            icon,
          ],
          
        ),
      ),
    );
  }
}