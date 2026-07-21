import 'package:alpha_app/models/reward_model.dart';
import 'package:flutter/material.dart';

class RewardProvider extends ChangeNotifier {
  RewardModel? _rewardData;

  bool _isLoading = false;

  RewardModel? get rewardData =>
      _rewardData;

  bool get isLoading => _isLoading;

  Future<void> loadRewards() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(
      const Duration(milliseconds: 400),
    );

    _rewardData = const RewardModel(
      level: 4,
      levelTitle: "Smart Saver",
      currentXp: 320,
      nextLevelXp: 500,
      badgeCount: 6,
      streak: 3,
      badges: [
        BadgeModel(
          id: "1",
          title: "Smart Saver",
          icon: "💰",
          isUnlocked: true,
        ),
        BadgeModel(
          id: "2",
          title: "Goal Achiever",
          icon: "🎯",
          isUnlocked: true,
        ),
        BadgeModel(
          id: "3",
          title: "7-Day Streak",
          icon: "🔥",
          isUnlocked: true,
        ),
        BadgeModel(
          id: "4",
          title: "Financial Master",
          icon: "🏆",
          isUnlocked: false,
        ),
      ],
      achievements: [
        AchievementModel(
          id: "1",
          title: "First goal achieved",
          isCompleted: true,
        ),
        AchievementModel(
          id: "2",
          title:
              "A full week on budget",
          isCompleted: true,
        ),
        AchievementModel(
          id: "3",
          title:
              "3 months of consistent saving",
          isCompleted: false,
        ),
      ],
    );

    _isLoading = false;
    notifyListeners();
  }

  void addXp(
    int amount,
  ) {
    if (_rewardData == null) return;

    final newXp =
        _rewardData!.currentXp + amount;

    var newLevel = _rewardData!.level;
    var newNextLevelXp =
        _rewardData!.nextLevelXp;
    var finalXp = newXp;

    if (newXp >= newNextLevelXp) {
      newLevel++;
      finalXp = newXp - newNextLevelXp;
      newNextLevelXp += 150;
    }

    _rewardData = RewardModel(
      level: newLevel,
      levelTitle: _rewardData!.levelTitle,
      currentXp: finalXp,
      nextLevelXp: newNextLevelXp,
      badgeCount:
          _rewardData!.badgeCount,
      streak: _rewardData!.streak,
      badges: _rewardData!.badges,
      achievements:
          _rewardData!.achievements,
    );

    notifyListeners();
  }
}