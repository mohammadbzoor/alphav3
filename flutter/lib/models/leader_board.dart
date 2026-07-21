class LeaderboardUserModel {
  final String id;
  final String name;

  final int level;
  final double progress;

  final int rank;

  final String medal;
  final bool isCurrentUser;

  const LeaderboardUserModel({
    required this.id,
    required this.name,
    required this.level,
    required this.progress,
    required this.rank,
    required this.medal,
    required this.isCurrentUser,
  });

  int get progressPercentage {
    return (progress.clamp(0.0, 1.0) * 100).round();
  }
}

class LeaderboardModel {
  final String title;
  final String subtitle;

  final bool isHidden;

  final List<LeaderboardUserModel> users;

  const LeaderboardModel({
    required this.title,
    required this.subtitle,
    required this.isHidden,
    required this.users,
  });

  LeaderboardUserModel? get winner {
    if (users.isEmpty) return null;

    final sortedUsers = [...users]
      ..sort(
        (first, second) =>
            second.progress.compareTo(
          first.progress,
        ),
      );

    return sortedUsers.first;
  }
}