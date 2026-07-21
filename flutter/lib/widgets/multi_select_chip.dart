import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/providers/themeprovider.dart' show Themeprovider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


class MultiSelectChip extends StatelessWidget {


  final List<String> items;

  final List<String> selectedItems;

  final Function(String) onTap;



  const MultiSelectChip({

    super.key,

    required this.items,

    required this.selectedItems,

    required this.onTap,

  });



  @override
  Widget build(BuildContext context) {

    final themeprovider = Provider.of<Themeprovider>(context);

    return SizedBox(

      height:50,


      child:ListView.builder(

        scrollDirection:
        Axis.horizontal,


        itemCount:
        items.length,


        itemBuilder:(context,index){


          final item =
          items[index];


          final selected =
          selectedItems.contains(item);



          return GestureDetector(


            onTap:(){

              onTap(item);

            },


            child:Container(


              margin:

              const EdgeInsets.only(

                right:10,

              ),



              padding:

              const EdgeInsets.symmetric(

                horizontal:18,

                vertical:12,

              ),



              decoration:

              BoxDecoration(


                color:

               
   selected

                  ?
(themeprovider.isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withOpacity(0.04) :
           (themeprovider.isDark ? AppColors.darkSubText : AppColors.lightSubText).withOpacity(.4),


                borderRadius:

                BorderRadius.circular(12),



                border:

                Border.all(

                  color:

                  selected

                      ?

               

               themeprovider.isDark ? AppColors.darkPrimary : AppColors.lightPrimary
                    :

                Colors.transparent,

                  width:1.5,

                ),

              ),




              child:Text(

                item,


                style:

                TextStyle(


                  color:

                   selected

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


        },

      ),

    );


  }


}