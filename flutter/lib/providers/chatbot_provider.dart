import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/chat_model.dart';
import '../services/chat_service.dart';

class ChatbotProvider extends ChangeNotifier {
  // ================= CONTROLLERS =================

  final TextEditingController messageController = TextEditingController();

  final TextEditingController voiceController = TextEditingController();

  // ================= SPEECH =================

  final SpeechToText speech = SpeechToText();

  bool isListening = false;

  String voiceText = "";

  // ================= CHAT =================

  int? conversationId;
  bool isLoading = false;

  List<ChatModel> messages = [
    ChatModel(
      message: "Hello, I’m Basira. How can I help you today?",
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

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || text.length > 2000) {
      return;
    }
    if (isLoading) return;

    final userMessage = ChatModel(
      message: text.trim(),
      isUser: true,
      isPending: true,
    );

    messages.add(userMessage);
    messageController.clear();
    suggestions = [];
    isLoading = true;
    notifyListeners();

    await _sendMessageToBackend(userMessage);
  }

  Future<void> _sendMessageToBackend(ChatModel userMessage) async {
    try {
      final response = await ChatService.sendMessage(
        conversationId: conversationId,
        message: userMessage.message,
      );

      if (response['success'] == true) {
        userMessage.isPending = false;
        
        if (response['conversationId'] != null) {
          conversationId = response['conversationId'] is int 
              ? response['conversationId'] 
              : int.tryParse(response['conversationId'].toString());
        }

        final assistantMessage = response['message'];
        if (assistantMessage != null) {
          messages.add(
            ChatModel(
              id: assistantMessage['id'] is int ? assistantMessage['id'] : int.tryParse(assistantMessage['id']?.toString() ?? ''),
              message: assistantMessage['content'] ?? '',
              isUser: false,
              time: assistantMessage['timestamp'] != null 
                  ? DateTime.tryParse(assistantMessage['timestamp']) 
                  : null,
            ),
          );

          if (assistantMessage['metadata'] != null && 
              assistantMessage['metadata']['suggestedQuestions'] != null) {
            final questions = assistantMessage['metadata']['suggestedQuestions'] as List;
            if (questions.isNotEmpty) {
              suggestions = questions.map((e) => e.toString()).toList();
            } else {
              suggestions = [];
            }
          } else {
            suggestions = [];
          }
        }
      } else {
        userMessage.isPending = false;
        userMessage.isFailed = true;
        
        final error = response['error'];
        messages.add(
          ChatModel(
            message: error != null && error['message'] != null 
                ? error['message'] 
                : "تعذر الحصول على الرد حاليًا، يرجى المحاولة لاحقًا.",
            isUser: false,
            isFailed: true,
          ),
        );
      }
    } catch (e) {
      userMessage.isPending = false;
      userMessage.isFailed = true;
      messages.add(
        ChatModel(
          message: "تعذر الحصول على الرد حاليًا، يرجى المحاولة لاحقًا.",
          isUser: false,
          isFailed: true,
        ),
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retryMessage(ChatModel failedMessage) async {
    if (isLoading || !failedMessage.isFailed || !failedMessage.isUser) return;
    
    // Remove the previous error message if it's the last one
    if (messages.isNotEmpty && !messages.last.isUser && messages.last.isFailed) {
      messages.removeLast();
    }

    failedMessage.isFailed = false;
    failedMessage.isPending = true;
    isLoading = true;
    notifyListeners();

    await _sendMessageToBackend(failedMessage);
  }

  void sendSuggestion(String value) {
    sendMessage(value);
  }

  // ================= VOICE =================

  Future<void> startListening() async {
    bool available = await speech.initialize(
      onStatus: (status) {
        if (status == "done") {
          isListening = false;

          notifyListeners();
        }
      },
      onError: (error) {
        isListening = false;

        notifyListeners();
      },
    );

    if (!available) {
      return;
    }

    isListening = true;

    notifyListeners();

    speech.listen(
      onResult: (result) {
        voiceText = result.recognizedWords;

        // يظهر داخل صفحة الصوت

        voiceController.text = voiceText;

        voiceController.selection = TextSelection.fromPosition(
          TextPosition(
            offset: voiceController.text.length,
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

  void clearVoice() {
    voiceText = "";

    voiceController.clear();

    notifyListeners();
  }

  @override
  void dispose() {
    messageController.dispose();

    voiceController.dispose();

    speech.stop();

    super.dispose();
  }
}
