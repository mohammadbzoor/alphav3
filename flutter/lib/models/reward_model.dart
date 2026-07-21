class BadgeModel {
  final String id;
  final String title;
  final String icon;
  final bool isUnlocked;

  const BadgeModel({
    required this.id,
    required this.title,
    required this.icon,
    required this.isUnlocked,
  });
}

class AchievementModel {
  final String id;
  final String title;
  final bool isCompleted;

  const AchievementModel({
    required this.id,
    required this.title,
    required this.isCompleted,
  });
}

class RewardModel {
  final int level;
  final String levelTitle;

  final int currentXp;
  final int nextLevelXp;

  final int badgeCount;
  final int streak;

  final List<BadgeModel> badges;
  final List<AchievementModel> achievements;

  const RewardModel({
    required this.level,
    required this.levelTitle,
    required this.currentXp,
    required this.nextLevelXp,
    required this.badgeCount,
    required this.streak,
    required this.badges,
    required this.achievements,
  });

  double get levelProgress {
    if (nextLevelXp <= 0) return 0;

    return (currentXp / nextLevelXp)
        .clamp(0.0, 1.0);
  }
}