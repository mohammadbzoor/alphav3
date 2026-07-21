import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/chat_model.dart';



class ChatbotProvider extends ChangeNotifier {



  // ================= CONTROLLERS =================


  final TextEditingController messageController =
  TextEditingController();



  final TextEditingController voiceController =
  TextEditingController();





  // ================= SPEECH =================



  final SpeechToText speech =
  SpeechToText();



  bool isListening = false;



  String voiceText = "";







  // ================= CHAT =================



  List<ChatModel> messages = [


    ChatModel(

      message:
      "Hello, I’m Basira. How can I help you today?",

      isUser: false,

    ),


  ];







  List<String> suggestions = [


    "How can I save money?",

    "Analyze my expenses",

    "Create saving plan",

    "Reduce my spending",


  ];









  // ================= SEND MESSAGE =================




  void sendMessage(String text){



    if(text.trim().isEmpty){

      return;

    }






    messages.add(



      ChatModel(


        message:text.trim(),


        isUser:true,


      ),


    );





    messageController.clear();





    notifyListeners();








    // Temporary response until API



    Future.delayed(



      const Duration(seconds:1),



          (){


        messages.add(



          ChatModel(


            message:

            "I received your message. Basira will help you soon.",



            isUser:false,


          ),



        );



        notifyListeners();



      },



    );



  }








  void sendSuggestion(String value){


    sendMessage(value);


  }









  // ================= VOICE =================







  Future<void> startListening() async {



    bool available =

    await speech.initialize(



      onStatus:(status){



        if(status == "done"){



          isListening = false;



          notifyListeners();



        }



      },



      onError:(error){



        isListening = false;



        notifyListeners();



      },


    );








    if(!available){

      return;

    }






    isListening = true;



    notifyListeners();








    speech.listen(



      onResult:(result){



        voiceText = result.recognizedWords;





        // يظهر داخل صفحة الصوت

        voiceController.text = voiceText;







        voiceController.selection =

        TextSelection.fromPosition(



          TextPosition(



            offset:

            voiceController.text.length,



          ),



        );







        notifyListeners();



      },



    );




  }









  Future<void> stopListening() async {



    await speech.stop();



    isListening = false;



    notifyListeners();



  }









  void clearVoice(){



    voiceText = "";



    voiceController.clear();



    notifyListeners();



  }









  @override
  void dispose(){



    messageController.dispose();



    voiceController.dispose();



    speech.stop();



    super.dispose();



  }




}