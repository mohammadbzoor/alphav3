class HomeModel {
  final String userName;
  final int financialScore;

  final double income;
  final double expenses;
  final double savings;

  final String scoreMessage;
  final String scoreLevel;

  final String todayInsight;

  final HomeGoal? goal;
  final HomeChallenge? challenge;

  const HomeModel({
    required this.userName,
    required this.financialScore,
    required this.income,
    required this.expenses,
    required this.savings,
    required this.scoreMessage,
    required this.scoreLevel,
    required this.todayInsight,
    this.goal,
    this.challenge,
  });

  factory HomeModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return HomeModel(
      userName:
          json["user_name"]?.toString() ??
          json["userName"]?.toString() ??
          "",

      financialScore: _toInt(
        json["financial_score"] ??
            json["financialScore"],
      ),

      income: _toDouble(
        json["income"],
      ),

      expenses: _toDouble(
        json["expenses"],
      ),

      savings: _toDouble(
        json["savings"],
      ),

      scoreMessage:
          json["score_message"]?.toString() ??
          json["scoreMessage"]?.toString() ??
          "",

      scoreLevel:
          json["score_level"]?.toString() ??
          json["scoreLevel"]?.toString() ??
          "",

      todayInsight:
          json["today_insight"]?.toString() ??
          json["todayInsight"]?.toString() ??
          "",

      goal: json["goal"] is Map<String, dynamic>
          ? HomeGoal.fromJson(
              json["goal"],
            )
          : null,

      challenge:
          json["challenge"] is Map<String, dynamic>
              ? HomeChallenge.fromJson(
                  json["challenge"],
                )
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "user_name": userName,
      "financial_score": financialScore,
      "income": income,
      "expenses": expenses,
      "savings": savings,
      "score_message": scoreMessage,
      "score_level": scoreLevel,
      "today_insight": todayInsight,
      "goal": goal?.toJson(),
      "challenge": challenge?.toJson(),
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? "",
        ) ??
        0;
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? "",
        ) ??
        0;
  }
}

class HomeGoal {
  final String id;
  final String name;
  final double progress;

  const HomeGoal({
    required this.id,
    required this.name,
    required this.progress,
  });

  factory HomeGoal.fromJson(
    Map<String, dynamic> json,
  ) {
    return HomeGoal(
      id: json["id"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      progress: _normalizeProgress(
        json["progress"],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "progress": progress,
    };
  }

  static double _normalizeProgress(
    dynamic value,
  ) {
    double progress;

    if (value is num) {
      progress = value.toDouble();
    } else {
      progress = double.tryParse(
            value?.toString() ?? "",
          ) ??
          0;
    }

    if (progress > 1) {
      progress = progress / 100;
    }

    return progress.clamp(0.0, 1.0);
  }
}

class HomeChallenge {
  final String id;
  final String name;
  final double progress;

  const HomeChallenge({
    required this.id,
    required this.name,
    required this.progress,
  });

  factory HomeChallenge.fromJson(
    Map<String, dynamic> json,
  ) {
    return HomeChallenge(
      id: json["id"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      progress: _normalizeProgress(
        json["progress"],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "progress": progress,
    };
  }

  static double _normalizeProgress(
    dynamic value,
  ) {
    double progress;

    if (value is num) {
      progress = value.toDouble();
    } else {
      progress = double.tryParse(
            value?.toString() ?? "",
          ) ??
          0;
    }

    if (progress > 1) {
      progress = progress / 100;
    }

    return progress.clamp(0.0, 1.0);
  }
}