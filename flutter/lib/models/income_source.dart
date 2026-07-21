import 'package:flutter/material.dart';


class IncomeSource {


  String name;


  bool selected;


  double amount;


  String frequency;


  DateTime? collectionDate;


  String type;



  final TextEditingController controller;



  IncomeSource({

    required this.name,

    this.selected = false,

    this.amount = 0,

    this.frequency = "Monthly",

    this.collectionDate,

    this.type = "Permanent",

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


      "name": name,


      "amount": amount,


      "frequency": frequency,


      "collection_date":

      collectionDate?.toIso8601String(),


      "type": type,


    };


  }



}