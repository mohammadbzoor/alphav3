import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


class ChatInput extends StatelessWidget {


  final TextEditingController controller;

  final Function(String) onSend;

  final VoidCallback onVoice;



  const ChatInput({

    super.key,

    required this.controller,

    required this.onSend,

    required this.onVoice,

  });



  @override
  Widget build(BuildContext context) {

final screenW = Device.width(context);
    final screenH = Device.height(context);
    final themeprovider = Provider.of<Themeprovider>(context);

    return Container(


      padding:

      EdgeInsets.symmetric(

        horizontal: 12,

        vertical: 8,

      ),



      decoration:

      BoxDecoration(


        color:

       themeprovider.isDark ? AppColors.darkBorder : AppColors.lightBorder,



        borderRadius:

        BorderRadius.circular(25),


      ),



      child:

      Row(

        children: [



          Expanded(

            child:

            TextField(


              controller: controller,


              style:

              TextStyle(

                color: themeprovider.isDark ? AppColors.darkText : AppColors.lightText,
                fontWeight: FontWeight.w400,

              ),



              decoration:

              InputDecoration(

                hintText:
                "Ask Basira anything...",


                hintStyle:
                TextStyle(

                  color: themeprovider.isDark ? AppColors.darkSubText : AppColors.lightSubText,

                ),


                border: InputBorder.none,

              ),



            ),

          ),




          IconButton(

            onPressed: onVoice,


            icon:

             Icon(

              Icons.mic,

              color: themeprovider.isDark ? AppColors.darkSecondary : AppColors.lightSecondary,

            ),

          ),




          IconButton(

            onPressed: (){


              onSend(controller.text);


            },


            icon:

         Icon(

              Icons.send,

              color:(themeprovider.isDark ? AppColors.darkSecondary : AppColors.lightSecondary)
            ),

          ),



        ],


      ),


    );


  }


}