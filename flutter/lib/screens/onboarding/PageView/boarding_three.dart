import 'package:alpha_app/media/images.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/widgets/Custom_mesh_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class BoardingThree extends StatefulWidget {
  const BoardingThree({super.key});

  @override
  State<BoardingThree> createState() => _BoardingThreeState();
}

class _BoardingThreeState extends State<BoardingThree> {
  @override
  Widget build(BuildContext context) {
   final double screenW = Device.width(context);
    final double screenH = Device.height(context);
    final themeprovider = Provider.of<Themeprovider>(context);
    return 
   
     Center(
        child: Column(
         
             
             
          children: [
           
            Padding(
              padding: EdgeInsets.only(top: screenH*0.08),
              child: CustomMeshCard(hight: screenH*0.4 , width: screenW*0.8 ,isDark: themeprovider.isDark, imagepath: ImagesAssets.boarding3),
            ),
             SizedBox(height: screenH*0.04),
              
            Text(
              "Reach Your Goals, Smartly",
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: screenW*0.07,
                fontWeight: FontWeight.bold,
                color: themeprovider.isDark
                    ? AppColors.darkText
                    : AppColors.lightText,
              ),
            ),
               SizedBox(height: screenH*0.03),
            Expanded(
              child: Text( 'Track your goals, compete with friends through fun challenges, and rest assured your financial data stays fully protected and never shared' ,
                textAlign: TextAlign.center,
       
style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: screenW*0.042,
                 
                  color: themeprovider.isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                ),
              ),
            ),
            
           
          ],
        ),
      );
  }
}