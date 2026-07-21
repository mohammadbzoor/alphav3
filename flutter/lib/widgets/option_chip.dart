import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


class OptionChip extends StatelessWidget {


  final List<String> items;

  final String? selected;

  final Function(String) onTap;



  const OptionChip({

    super.key,

    required this.items,

    required this.selected,

    required this.onTap,

  });





  @override
  Widget build(BuildContext context) {
    final themeprovider = Provider.of<Themeprovider>(context);

    return Wrap(

      spacing: 10,

      runSpacing: 10,


      children: items.map((item){


        final isSelected =
            item == selected;



        return GestureDetector(


          onTap: (){

            onTap(item);

          },


          child: Container(


            padding:
            const EdgeInsets.symmetric(

              horizontal:18,

              vertical:12,

            ),



            decoration: BoxDecoration(


              color:

              isSelected

                  ?
(themeprovider.isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withOpacity(0.04) :
            
                  (themeprovider.isDark ? AppColors.darkSubText : AppColors.lightSubText).withOpacity(.4),

                 
          



              borderRadius:

              BorderRadius.circular(12),




              border: Border.all( width:1.5,


                color:

                isSelected

                    ?

               themeprovider.isDark ? AppColors.darkPrimary : AppColors.lightPrimary
                    :

                Colors.transparent,



                


              ),



            ),



            child: Text(


              item,


              style: TextStyle(


                color:

                isSelected

                    ?
      themeprovider.isDark ? AppColors.darkPrimary : AppColors.lightPrimary

                    :

                (themeprovider.isDark ? AppColors.darkSubText : AppColors.lightSubText),



                fontWeight:

                FontWeight.w600,


              ),


            ),


          ),


        );



      }).toList(),


    );


  }


}