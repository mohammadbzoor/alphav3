class NotificationModel {
  final String id;
  final String type; // info, success, warning, critical
  final String category;
  final String title;
  final String message;
  final Map<String, dynamic>? actionData;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.message,
    this.actionData,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'].toString(),
      type: json['type']?.toString() ?? 'info',
      category: json['category']?.toString() ?? 'system',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      actionData: json['actionData'] != null ? Map<String, dynamic>.from(json['actionData']) : null,
      isRead: json['isRead'] == 1 || json['isRead'] == true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }
}
