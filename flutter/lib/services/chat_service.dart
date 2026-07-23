import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class ChatService {
  static Future<Map<String, dynamic>> sendMessage({
    int? conversationId,
    required String message,
    String intent = 'chat',
    String language = 'ar',
    Map<String, dynamic>? contextData,
  }) async {
    final body = {
      'conversationId': conversationId,
      'message': message,
      'intent': intent,
      'language': language,
      if (contextData != null) 'context': contextData,
    };

    final response = await ApiService.post('/chat/messages', body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return json;
    } else {
      try {
        final json = jsonDecode(response.body);
        return json;
      } catch (e) {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    }
  }
}
