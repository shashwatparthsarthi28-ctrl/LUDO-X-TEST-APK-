import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';

/// Bottom-navigation shell. Tabs are kept alive; a refresh counter makes each
/// tab reload its data when selected.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;
  final List<int> _stamp = [0, 0, 0, 0];

  void goTo(int i) {
    setState(() {
      _stamp[i]++;
      _i = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(key: ValueKey('home${_stamp[0]}'), goTo: goTo),
      WalletScreen(key: ValueKey('wallet${_stamp[1]}')),
      LeaderboardScreen(key: ValueKey('rank${_stamp[2]}')),
      ProfileScreen(key: ValueKey('profile${_stamp[3]}')),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _i, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: goTo,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          const NavigationDestination(icon: Icon(Icons.leaderboard_outlined), selectedIcon: Icon(Icons.leaderboard), label: 'Ranks'),
          NavigationDestination(
            icon: Badge(isLabelVisible: app.unread > 0, label: Text('${app.unread}'), child: const Icon(Icons.person_outline)),
            selectedIcon: const Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
