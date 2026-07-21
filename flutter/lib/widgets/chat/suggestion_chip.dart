import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


class SuggestionChipWidget extends StatelessWidget {


  final String text;

  final VoidCallback onTap;



  const SuggestionChipWidget({

    super.key,

    required this.text,

    required this.onTap,

  });



  @override
  Widget build(BuildContext context) {
final screenW = Device.width(context);
    final screenH = Device.height(context);
    final themeprovider = Provider.of<Themeprovider>(context);


    return GestureDetector(

      onTap: onTap,


      child: Container(


        padding:

        EdgeInsets.symmetric(

          horizontal: screenW*0.04,

          vertical: screenH*0.015,

        ),



        margin:

        EdgeInsets.only(right: screenW*0.02),



        decoration:

        BoxDecoration(


          color:

         (themeprovider.isDark ? AppColors.darkAccent : AppColors.lightAccent).withOpacity(0.3),



          borderRadius:

          BorderRadius.circular(20),



          border:

          Border.all( width: 1.5,

            color:

            themeprovider.isDark ? AppColors.darkAccent: AppColors.lightAccent

          ),


        ),



        child:

        Text(

          text,


          style:

        TextStyle(

            color: (themeprovider.isDark ? AppColors.darkAccent : AppColors.lightAccent),

            fontWeight: FontWeight.w600,
            fontSize: screenW*0.04,

          ),


        ),


      ),

    );


  }

}