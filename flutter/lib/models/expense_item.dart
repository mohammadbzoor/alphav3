import 'package:flutter/material.dart';



class ExpenseItem {


  String name;


  bool selected;


  double amount;


  String frequency;



  final TextEditingController controller;





  ExpenseItem({

    required this.name,

    this.selected = false,

    this.amount = 0,

    this.frequency = "Monthly",

  }) : controller = TextEditingController();







  String get displayAmount {


    if(amount == 0){

      return "";

    }


    if(amount % 1 == 0){

      return amount.toInt().toString();

    }


    return amount.toString();


  }







  Map<String,dynamic> toJson(){


    return {


      "name":name,


      "amount":amount,


      "frequency":frequency,


    };


  }




}