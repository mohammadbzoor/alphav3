import 'package:flutter/material.dart';

class CustomMeshCard extends StatelessWidget {
   String imagepath ;
  bool isDark ;
 double hight;
 double width ;
 CustomMeshCard({  required this.width,required this.hight,  required this.isDark,required this.imagepath ,super.key});

  @override
  Widget build(BuildContext context) {
    return Container( 
      height: hight ,
      width: width ,
     decoration: BoxDecoration( 
      gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark ?

          [
             Color(0xFF45462D).withOpacity(0.55),
        const Color(0xFF155448).withOpacity(0.65),
        const Color(0xFF0F3E38).withOpacity(0.8),
          ]
            
              

             

              : [Color(0xFFF2E9d1), 
                  Color(0xFFFFFFFF), 
                  Color(0xFFC7F0E7),],
        ),
      borderRadius: BorderRadius.circular(30),
     
     ),

     child: Padding(
      padding: EdgeInsets.all(width * 0.25),
       child: Image.asset(imagepath ,fit: BoxFit.contain,),
     ),
    );
  }
}