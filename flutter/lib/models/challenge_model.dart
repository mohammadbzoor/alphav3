enum ChallengeType {
  individual,
  team,
}

enum ChallengeStatus {
  current,
  completed,
  available,
}

class ChallengeModel {
  final String id;
  final String? templateId;
  final String title;
  final String description;

  final ChallengeType type;
  final ChallengeStatus status;

  final double progress;

  final int totalDays;
  final int daysLeft;

  final int xpReward;
  final String icon;

  final bool isAccepted;

  const ChallengeModel({
    required this.id,
    this.templateId,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.progress,
    required this.totalDays,
    required this.daysLeft,
    required this.xpReward,
    required this.icon,
    required this.isAccepted,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    ChallengeType parsedType = ChallengeType.individual;
    if (json['type'] == 'team') parsedType = ChallengeType.team;

    ChallengeStatus parsedStatus = ChallengeStatus.available;
    if (json['status'] == 'current') parsedStatus = ChallengeStatus.current;
    if (json['status'] == 'completed') parsedStatus = ChallengeStatus.completed;

    return ChallengeModel(
      id: json['id']?.toString() ?? '',
      templateId: json['templateId']?.toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: parsedType,
      status: parsedStatus,
      progress: (json['progress'] ?? 0.0).toDouble(),
      totalDays: json['totalDays'] ?? 0,
      daysLeft: json['daysLeft'] ?? 0,
      xpReward: json['xpReward'] ?? 0,
      icon: json['icon'] ?? 'star',
      isAccepted: json['isAccepted'] ?? false,
    );
  }

  int get progressPercentage {
    return (progress.clamp(0.0, 1.0) * 100).round();
  }

  bool get isCompleted {
    return status == ChallengeStatus.completed || progress >= 1;
  }

  ChallengeModel copyWith({
    String? id,
    String? title,
    String? description,
    ChallengeType? type,
    ChallengeStatus? status,
    double? progress,
    int? totalDays,
    int? daysLeft,
    int? xpReward,
    String? icon,
    bool? isAccepted,
  }) {
    return ChallengeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      totalDays: totalDays ?? this.totalDays,
      daysLeft: daysLeft ?? this.daysLeft,
      xpReward: xpReward ?? this.xpReward,
      icon: icon ?? this.icon,
      isAccepted: isAccepted ?? this.isAccepted,
    );
  }
}
