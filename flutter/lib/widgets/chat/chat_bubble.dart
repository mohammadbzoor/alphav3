import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_model.dart';



class ChatBubble extends StatelessWidget {


  final ChatModel message;



  const ChatBubble({

    super.key,

    required this.message,

  });





  @override
  Widget build(BuildContext context) {

 final screenW = Device.width(context);
    final screenH = Device.height(context);
    final themeprovider = Provider.of<Themeprovider>(context);

    return Align(



      alignment:

      message.isUser

          ?

      Alignment.centerRight

          :

      Alignment.centerLeft,





      child:

      Container(



        margin:

        EdgeInsets.symmetric(

          vertical: 6,

        ),





        padding:

        const EdgeInsets.symmetric(

          horizontal: 14,

          vertical: 10,

        ),





        constraints:

        const BoxConstraints(

          maxWidth: 300,

        ),





        decoration:

        BoxDecoration(



          color:

          message.isUser

              ?

        (  themeprovider.isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withOpacity(0.5)

              :

         (themeprovider.isDark ? AppColors.darkSubText : AppColors.lightSubText).withOpacity(.4),





          borderRadius:

          BorderRadius.only(



            topLeft:

            const Radius.circular(16),



            topRight:

            const Radius.circular(16),



            bottomLeft:

            message.isUser

                ?

            const Radius.circular(16)

                :

            Radius.zero,



            bottomRight:

            message.isUser

                ?

            Radius.zero

                :

            const Radius.circular(16),



          ),



        ),






        child:

        Column(



          crossAxisAlignment:

          CrossAxisAlignment.end,



          children: [





            Align(



              alignment:

              Alignment.centerLeft,



              child:

              Text(



                message.message,



                style:

                TextStyle(



                  color:

                 message.isUser

                      ? themeprovider.isDark ? AppColors.darkPrimary : AppColors.lightPrimary
                      :
                      themeprovider.isDark ? AppColors.darkSubText : AppColors.lightSubText,


                  fontSize:screenW*0.045,
                  fontWeight: FontWeight.w500



                ),



              ),



            ),







           SizedBox(height: screenH*0.01,),







            Text(



              "${message.time.hour.toString().padLeft(2,'0')}:${message.time.minute.toString().padLeft(2,'0')}",



              style:

              TextStyle(



                color:

              themeprovider.isDark ? AppColors.darkText : AppColors.lightText,



                fontSize: screenW*0.03,
fontWeight: FontWeight.w400


              ),



            ),





          ],



        ),



      ),



    );



  }



}