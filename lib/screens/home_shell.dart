import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'activity_tab.dart';
import 'add_item_screen.dart';
import 'explore_tab.dart';
import 'home_tab.dart';
import 'profile_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late Future<void> _ready = Me.load();
  int _tab = 0;

  Future<void> _add() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AddItemScreen()));
    Me.version.value++;
  }

  Widget _nav(int index, IconData icon, String label) {
    final active = _tab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? AppColors.green : AppColors.grey, size: 26),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.green : AppColors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Loading());
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: ErrorBox(snap.error!,
                  onRetry: () => setState(() => _ready = Me.load())),
            ),
          );
        }
        return ValueListenableBuilder<int>(
          valueListenable: Me.version,
          builder: (context, v, _) {
            final pages = <Widget>[
              HomeTab(key: ValueKey('home$v'), onTab: (i) => setState(() => _tab = i)),
              ExploreTab(key: ValueKey('explore$v')),
              ActivityTab(key: ValueKey('activity$v')),
              ProfileTab(key: ValueKey('profile$v')),
            ];
            return Scaffold(
              body: SafeArea(bottom: false, child: IndexedStack(index: _tab, children: pages)),
              bottomNavigationBar: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        _nav(0, Icons.home_rounded, 'Home'),
                        _nav(1, Icons.search_rounded, 'Explore'),
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              onTap: _add,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  color: AppColors.green,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Color(0x332F7D5B),
                                        blurRadius: 12,
                                        offset: Offset(0, 4)),
                                  ],
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 28),
                              ),
                            ),
                          ),
                        ),
                        _nav(2, Icons.swap_horiz_rounded, 'Activity'),
                        _nav(3, Icons.person_rounded, 'Profile'),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
