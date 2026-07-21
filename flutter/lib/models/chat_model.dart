class ChatModel {


  final String message;

  final bool isUser;

  final DateTime time;



  ChatModel({

    required this.message,

    required this.isUser,

    DateTime? time,

  }) : time = time ?? DateTime.now();



}