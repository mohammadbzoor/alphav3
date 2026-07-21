import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


class CustomPhoneField extends StatelessWidget {

  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;


  const CustomPhoneField({
    super.key,
    required this.controller,
    this.hint = "79XXXXXXX",
    this.validator,
    this.onChanged,
  });


  @override
  Widget build(BuildContext context) {

    final double screenW = Device.width(context);
    final double screenH = Device.height(context);

    final themeprovider =
        Provider.of<Themeprovider>(context);


    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenW * 0.02,
      ),

      child: Row(
        children: [


          Container(

            height: screenH*0.08,

            padding:  EdgeInsets.symmetric(
              horizontal: screenW*0.02,
            ),

            decoration: BoxDecoration(

              color: themeprovider.isDark
                  ? AppColors.darkBackground
                  : AppColors.lightBackground,

              borderRadius:
              BorderRadius.circular(12),

              border: Border.all(
                color: themeprovider.isDark
                    ? AppColors.darkSubText
                    : AppColors.lightSubText,
              ),
            ),


            child: Row(
              mainAxisAlignment:
              MainAxisAlignment.center,

              children: [

                 Text(
                  "🇯🇴",
                  style: TextStyle(
                    fontSize: screenW*0.055,
                  ),
                ),


                 SizedBox(width: screenW*0.01),


                Text(
                  "+962",
                  style: TextStyle(

                    color: themeprovider.isDark
                        ? AppColors.darkText
                        : AppColors.lightText,

                    fontWeight:
                    FontWeight.w600,

                    fontSize: screenW * 0.04,
                  ),
                ),

              ],
            ),
          ),



       SizedBox(width: screenW*0.02),



          Expanded(

            child: TextFormField(
textDirection: TextDirection.ltr,
              controller: controller,

              keyboardType:
              TextInputType.phone,

              onChanged: onChanged,


              validator: validator,


              style: TextStyle(
                color: themeprovider.isDark
                    ? AppColors.darkText
                    : AppColors.lightText,
              ),



              decoration: InputDecoration(

                hintText: hint,


                hintStyle: TextStyle(
                  color: themeprovider.isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                ),


                prefixIcon: Icon(
                  Icons.phone,
                  color: themeprovider.isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                  size: screenW * 0.06,
                ),



                filled: true,


                fillColor:
                themeprovider.isDark
                    ? AppColors.darkBackground
                    : AppColors.lightBackground,



                focusedBorder:
                OutlineInputBorder(

                  borderRadius:
                  BorderRadius.circular(12),

                  borderSide:
                  BorderSide(

                    color: themeprovider.isDark
                        ? AppColors.darkPrimary
                        : AppColors.lightPrimary,

                    width: 1.5,
                  ),
                ),



                enabledBorder:
                OutlineInputBorder(

                  borderRadius:
                  BorderRadius.circular(12),

                  borderSide:
                  BorderSide(

                    color: themeprovider.isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                  ),
                ),



                errorBorder:
                OutlineInputBorder(

                  borderRadius:
                  BorderRadius.circular(12),

                  borderSide:
                  const BorderSide(
                    color: Colors.red,
                  ),
                ),
focusedErrorBorder:
                OutlineInputBorder(


                  borderRadius:
                  BorderRadius.circular(12),



                  borderSide:
                  const BorderSide(

                    color: Colors.red,

                    width: 1.5,

                  ),

                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}