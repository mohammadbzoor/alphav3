import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/themeprovider.dart' show Themeprovider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


enum TextFieldType {
  name,
  email,
  phone,
  password,
  date,
  number
}


class CustomTextfield extends StatefulWidget {

  final TextEditingController controller;
  final String hint;
  final IconData? icon;

  final TextFieldType type;

  final Widget? suffix;

  final String? Function(String?)? validator;

  final Function(String)? onChanged;

  final bool enabled;

final VoidCallback? onTap;
final bool readOnly;
  const CustomTextfield({
    super.key,
    required this.controller,
    required this.hint,
    required this.type,
    this.icon,
    this.suffix,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.onTap,
    this.readOnly = false
  });


  @override
  State<CustomTextfield> createState() =>
      _CustomTextfieldState();
}



class _CustomTextfieldState extends State<CustomTextfield> {


  bool isSecure = true;



  @override
  Widget build(BuildContext context) {


    final double screenW = Device.width(context);
 final themeprovider = Provider.of<Themeprovider>(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenW * 0.02,
      ),

      child: TextFormField(
onTap: widget.onTap,
readOnly: widget.readOnly,
        controller: widget.controller,


        enabled: widget.enabled,


        obscureText:
        widget.type == TextFieldType.password
            ? isSecure
            : false,


        keyboardType: _keyboardType(),


        textInputAction:
        TextInputAction.next,


        onChanged: widget.onChanged,


        validator: widget.validator,



        style: TextStyle(
          color: themeprovider.isDark ? AppColors.darkText : AppColors.lightText
        ),



        decoration: InputDecoration(


          hintText: widget.hint,


          hintStyle: TextStyle(
            color: themeprovider.isDark ? AppColors.darkSubText : AppColors.lightSubText
          ),



          prefixIcon: widget.icon != null
              ? Icon(
            widget.icon,
             color: themeprovider.isDark ? AppColors.darkSubText : AppColors.lightSubText,
            size: screenW * 0.06,
          )
              : null,



          suffixIcon:
          widget.type == TextFieldType.password

              ? IconButton(

            onPressed: (){
              setState(() {
                isSecure = !isSecure;
              });
            },


            icon: Icon(
              isSecure
                  ? Icons.visibility_off
                  : Icons.visibility,

               color: themeprovider.isDark ? AppColors.darkSubText : AppColors.lightSubText,
            ),

          )


              : widget.suffix,



          filled: true,


          fillColor:
         themeprovider.isDark ? AppColors.darkBackground : AppColors.lightBackground,



          focusedBorder:
          OutlineInputBorder(

            borderRadius:
            BorderRadius.circular(12),

            borderSide:
            BorderSide(
              color:
             themeprovider.isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              width: 1.5,
            ),
          ),



          enabledBorder:
          OutlineInputBorder(

            borderRadius:
            BorderRadius.circular(12),

            borderSide:
            BorderSide(
               color: themeprovider.isDark ? AppColors.darkSubText : AppColors.lightSubText
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


        ),
      ),
    );
  }




  TextInputType _keyboardType(){

    switch(widget.type){

      case TextFieldType.email:
        return TextInputType.emailAddress;


      case TextFieldType.phone:
        return TextInputType.phone;


      case TextFieldType.date:
        return TextInputType.datetime;


      case TextFieldType.name:
        return TextInputType.name;


      case TextFieldType.password:
        return TextInputType.visiblePassword;

      case TextFieldType.number:
        return TextInputType.number;

    }

  }


}