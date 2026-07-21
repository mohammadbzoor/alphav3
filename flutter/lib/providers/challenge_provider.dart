import 'package:alpha_app/models/challenge_model.dart';
import 'package:flutter/material.dart';

class ChallengeProvider extends ChangeNotifier {
  final List<ChallengeModel> _challenges = [];

  bool _isLoading = false;
  String? _errorMessage;

  ChallengeType _selectedType =
      ChallengeType.individual;

  ChallengeStatus _selectedStatus =
      ChallengeStatus.current;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  ChallengeType get selectedType =>
      _selectedType;

  ChallengeStatus get selectedStatus =>
      _selectedStatus;

  List<ChallengeModel> get challenges =>
      List.unmodifiable(_challenges);

  List<ChallengeModel> get filteredChallenges {
    return _challenges.where((challenge) {
      return challenge.type == _selectedType &&
          challenge.status == _selectedStatus;
    }).toList();
  }

  List<ChallengeModel> get activeChallenges {
    return _challenges.where((challenge) {
      return challenge.status ==
              ChallengeStatus.current &&
          challenge.isAccepted;
    }).toList();
  }

  ChallengeModel? get firstActiveChallenge {
    if (activeChallenges.isEmpty) {
      return null;
    }

    return activeChallenges.first;
  }

  Future<void> loadChallenges() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.delayed(
        const Duration(milliseconds: 450),
      );

      _challenges
        ..clear()
        ..addAll(
          const [
            ChallengeModel(
              id: "1",
              title:
                  "Cut your spending by 20% this week",
              description:
                  "Spend less than your previous weekly average.",
              type: ChallengeType.individual,
              status: ChallengeStatus.current,
              progress: 0.80,
              totalDays: 7,
              daysLeft: 4,
              xpReward: 120,
              icon: "🎯",
              isAccepted: true,
            ),
            ChallengeModel(
              id: "2",
              title:
                  "A week with no coffee shops",
              description:
                  "Avoid spending at coffee shops for seven days.",
              type: ChallengeType.individual,
              status: ChallengeStatus.current,
              progress: 0.55,
              totalDays: 7,
              daysLeft: 2,
              xpReward: 90,
              icon: "☕",
              isAccepted: true,
            ),
            ChallengeModel(
              id: "3",
              title:
                  "Save 25 JD this week",
              description:
                  "Build a small saving habit.",
              type: ChallengeType.individual,
              status: ChallengeStatus.available,
              progress: 0,
              totalDays: 7,
              daysLeft: 7,
              xpReward: 100,
              icon: "💰",
              isAccepted: false,
            ),
            ChallengeModel(
              id: "4",
              title:
                  "Record expenses every day",
              description:
                  "Add at least one expense per day.",
              type: ChallengeType.individual,
              status: ChallengeStatus.completed,
              progress: 1,
              totalDays: 7,
              daysLeft: 0,
              xpReward: 80,
              icon: "✅",
              isAccepted: true,
            ),
          ],
        );
    } catch (error) {
      _errorMessage =
          "Unable to load challenges";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectType(
    ChallengeType type,
  ) {
    _selectedType = type;
    notifyListeners();
  }

  void selectStatus(
    ChallengeStatus status,
  ) {
    _selectedStatus = status;
    notifyListeners();
  }

  void acceptChallenge(
    String challengeId,
  ) {
    final index = _challenges.indexWhere(
      (challenge) =>
          challenge.id == challengeId,
    );

    if (index == -1) return;

    _challenges[index] =
        _challenges[index].copyWith(
      isAccepted: true,
      status: ChallengeStatus.current,
    );

    notifyListeners();
  }

  void updateProgress({
    required String challengeId,
    required double progress,
  }) {
    final index = _challenges.indexWhere(
      (challenge) =>
          challenge.id == challengeId,
    );

    if (index == -1) return;

    final safeProgress =
        progress.clamp(0.0, 1.0);

    _challenges[index] =
        _challenges[index].copyWith(
      progress: safeProgress,
      status: safeProgress >= 1
          ? ChallengeStatus.completed
          : ChallengeStatus.current,
      daysLeft: safeProgress >= 1
          ? 0
          : _challenges[index].daysLeft,
    );

    notifyListeners();
  }

  void removeChallenge(
    String challengeId,
  ) {
    _challenges.removeWhere(
      (challenge) =>
          challenge.id == challengeId,
    );

    notifyListeners();
  }
}