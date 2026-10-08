import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'explore_tab.dart';
import 'item_detail.dart';
import 'need_screen.dart';

class HomeTab extends StatefulWidget {
  final ValueChanged<int> onTab;
  const HomeTab({super.key, required this.onTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<List<Json>> _items = fetchItems();
  late Future<Json?> _impact = fetchImpact();

  Future<void> _refresh() async {
    setState(() {
      _items = fetchItems();
      _impact = fetchImpact();
    });
    await _items;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.green,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('${greeting()}, ${Me.firstName}',
              style: const TextStyle(fontSize: 15, color: AppColors.grey)),
          const SizedBox(height: 4),
          const Text('What do you need?',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => widget.onTab(1),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(27),
                border: Border.all(color: AppColors.line),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, color: AppColors.grey),
                  SizedBox(width: 10),
                  Text('Search for something to borrow...',
                      style: TextStyle(color: AppColors.grey, fontSize: 15)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const NeedScreen())),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('I need something',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text('Describe what you are trying to do.\nWe will find what helps.',
                            style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 14, height: 1.35)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final e in kCategories.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ExploreScreen(initialCategory: e.key)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          children: [
                            Icon(kCategoryIcons[e.key], size: 18, color: AppColors.green),
                            const SizedBox(width: 8),
                            Text(e.value,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SectionTitle('Nearby'),
          FutureBuilder<List<Json>>(
            future: _items,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Loading();
              if (snap.hasError) return ErrorBox(snap.error!, onRetry: _refresh);
              final items = snap.data!
                ..sort((a, b) => itemDistance(a).compareTo(itemDistance(b)));
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.search_rounded,
                  title: 'Nothing nearby yet',
                  subtitle: 'Be the first to share something in your community.',
                );
              }
              return Column(
                children: [
                  for (final it in items)
                    ItemCard(
                      item: it,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ItemDetailScreen(item: it)),
                      ),
                    ),
                ],
              );
            },
          ),
          FutureBuilder<Json?>(
            future: _impact,
            builder: (context, snap) {
              final s = snap.data;
              if (s == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Community impact',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 10),
                    Text('${s['items_shared']} items kept in circulation',
                        style: const TextStyle(fontSize: 15)),
                    Text('${s['successful_borrows']} successful borrows',
                        style: const TextStyle(fontSize: 15)),
                    Text('${s['active_lenders']} active lenders',
                        style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 8),
                    const Text('Counts come from completed borrows recorded in Lendly.',
                        style: TextStyle(fontSize: 12, color: AppColors.grey)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
