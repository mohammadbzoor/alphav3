import 'package:flutter/material.dart';
import 'package:alpha_app/services/api_service.dart';
import 'package:alpha_app/models/notification_model.dart';
import 'dart:convert';

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/notifications');
      if (ApiService.isSuccess(response)) {
        final body = await ApiService.parseJson(response);
        if (body['success'] == true) {
          final data = body['data'];
          final items = data['items'] as List;
          _notifications = items.map((e) => NotificationModel.fromJson(e)).toList();
          _unreadCount = data['unreadCount'] ?? 0;
        }
      } else {
        _errorMessage = 'Failed to load notifications';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final response = await ApiService.get('/notifications/unread-count');
      if (ApiService.isSuccess(response)) {
        final body = await ApiService.parseJson(response);
        if (body['success'] == true) {
          _unreadCount = body['data']['unreadCount'] ?? 0;
          notifyListeners();
        }
      }
    } catch (e) {
      // fail silently for background unread count fetch
    }
  }

  Future<void> markAsRead(String id) async {
    // Optimistic update
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = NotificationModel(
        id: _notifications[index].id,
        type: _notifications[index].type,
        category: _notifications[index].category,
        title: _notifications[index].title,
        message: _notifications[index].message,
        actionData: _notifications[index].actionData,
        isRead: true,
        createdAt: _notifications[index].createdAt,
      );
      if (_unreadCount > 0) _unreadCount--;
      notifyListeners();
    }

    try {
      await ApiService.put('/notifications/$id/read');
    } catch (e) {
      // Handle error, maybe revert optimistic update
    }
  }

  Future<void> markAllAsRead() async {
    // Optimistic update
    _notifications = _notifications.map((n) {
      if (!n.isRead) {
        return NotificationModel(
          id: n.id,
          type: n.type,
          category: n.category,
          title: n.title,
          message: n.message,
          actionData: n.actionData,
          isRead: true,
          createdAt: n.createdAt,
        );
      }
      return n;
    }).toList();
    _unreadCount = 0;
    notifyListeners();

    try {
      await ApiService.put('/notifications/read-all');
    } catch (e) {
      // Revert if needed
    }
  }
}
