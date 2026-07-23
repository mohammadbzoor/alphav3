class ChatModel {
  final int? id;
  final String message;
  final bool isUser;
  final DateTime time;
  bool isPending;
  bool isFailed;

  ChatModel({
    this.id,
    required this.message,
    required this.isUser,
    DateTime? time,
    this.isPending = false,
    this.isFailed = false,
  }) : time = time ?? DateTime.now();
}
