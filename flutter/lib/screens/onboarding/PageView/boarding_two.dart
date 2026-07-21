import 'package:alpha_app/media/images.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/widgets/Custom_mesh_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class BoardingTwo extends StatefulWidget {
  const BoardingTwo({super.key});

  @override
  State<BoardingTwo> createState() => _BoardingTwoState();
}

class _BoardingTwoState extends State<BoardingTwo> {
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
              child: CustomMeshCard(hight: screenH*0.4 , width: screenW*0.8 ,isDark: themeprovider.isDark, imagepath: ImagesAssets.boarding2),
            ),
             SizedBox(height: screenH*0.04),
              
            Text(
              "Ask Before You Buy",
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
              child: Text( 'Before any purchase, ask Basira: "Does this fit my budget?" and get an instant read on its impact on your goals' ,
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