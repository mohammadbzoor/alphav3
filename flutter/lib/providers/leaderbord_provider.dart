import 'package:alpha_app/models/leader_board.dart';

import 'package:flutter/material.dart';

class LeaderboardProvider
    extends ChangeNotifier {
  LeaderboardModel? _leaderboard;

  bool _isLoading = false;

  LeaderboardModel? get leaderboard =>
      _leaderboard;

  bool get isLoading => _isLoading;

  Future<void> loadLeaderboard() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(
      const Duration(milliseconds: 450),
    );

    _leaderboard = const LeaderboardModel(
      title: "Leaderboard",
      subtitle: "Group savings challenge",
      isHidden: true,
      users: [
        LeaderboardUserModel(
          id: "1",
          name: "Ahmad",
          level: 5,
          progress: 0.90,
          rank: 1,
          medal: "🥇",
          isCurrentUser: false,
        ),
        LeaderboardUserModel(
          id: "2",
          name: "You",
          level: 4,
          progress: 0.85,
          rank: 2,
          medal: "🥈",
          isCurrentUser: true,
        ),
        LeaderboardUserModel(
          id: "3",
          name: "Sara",
          level: 4,
          progress: 0.75,
          rank: 3,
          medal: "🥉",
          isCurrentUser: false,
        ),
        LeaderboardUserModel(
          id: "4",
          name: "Yazan",
          level: 3,
          progress: 0.62,
          rank: 4,
          medal: "",
          isCurrentUser: false,
        ),
      ],
    );

    _isLoading = false;
    notifyListeners();
  }
}