import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'item_detail.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late Future<Json> _stats = trustStats(Me.id);

  Future<void> _refresh() async {
    await Me.load();
    setState(() => _stats = trustStats(Me.id));
    await _stats;
  }

  Widget _stat(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grey, fontSize: 12)),
      ],
    ),
  );

  Widget _row(IconData icon, String label, VoidCallback onTap) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: Icon(icon, color: AppColors.green),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
    onTap: onTap,
  );

  Future<List<Json>> _myItems() async {
    final r = await supabase
        .from('items')
        .select(kItemSelect)
        .eq('owner_id', Me.id)
        .order('created_at', ascending: false);
    return List<Json>.from(r);
  }

  Future<List<Json>> _savedItems() async {
    final r = await supabase
        .from('saved_items')
        .select('items($kItemSelect)')
        .eq('user_id', Me.id);
    return [
      for (final row in (r as List))
        if (row['items'] != null) Map<String, dynamic>.from(row['items'] as Map),
    ];
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final p = Me.profile ?? {};
    return RefreshIndicator(
      color: AppColors.green,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Center(
            child: Avatar(
                name: p['name'] as String?,
                url: p['profile_image'] as String?,
                radius: 44),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(p['name'] ?? '',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          ),
          Center(
            child: Text(Me.communityName, style: const TextStyle(color: AppColors.grey)),
          ),
          const SizedBox(height: 10),
          FutureBuilder<Json>(
            future: _stats,
            builder: (context, snap) {
              final s = snap.data ?? {};
              final lent = (s['items_lent'] as num?)?.toInt() ?? 0;
              final borrowed = (s['items_borrowed'] as num?)?.toInt() ?? 0;
              final total = (s['completed_total'] as num?)?.toInt() ?? 0;
              final disputes = (s['disputes_count'] as num?)?.toInt() ?? 0;
              final rate = (s['return_rate'] as num?)?.toInt() ?? 100;
              final trusted = total >= 3 && disputes == 0;
              return Column(
                children: [
                  if (trusted) const Center(child: Pill('Trusted Member')),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(children: [
                      _stat('$lent', 'Items lent'),
                      _stat('$borrowed', 'Items borrowed'),
                      _stat('$rate%', 'Returned on time'),
                    ]),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _row(Icons.inventory_2_outlined, 'My items', () => _open(ItemListScreen(
            title: 'My items',
            loader: _myItems,
            emptyTitle: 'No listings',
            emptyText: 'Your unused things could help someone nearby.',
          ))),
          _row(Icons.bookmark_border_rounded, 'Saved items', () => _open(ItemListScreen(
            title: 'Saved items',
            loader: _savedItems,
            emptyTitle: 'Nothing saved yet.',
            emptyText: 'Find something useful nearby.',
          ))),
          _row(Icons.verified_user_outlined, 'Trust & verification', () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Trust & verification'),
                content: const Text(
                  'Your trust profile is built from completed borrows, returns, '
                      'response time, and condition disputes. Ratings only count after '
                      'a completed transaction, so reputation cannot be faked.\n\n'
                      'Identity verification is coming soon.',
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context), child: const Text('OK'))
                ],
              ),
            );
          }),
          _row(Icons.shield_outlined, 'Community guidelines', () => _open(const GuidelinesScreen())),
          _row(Icons.logout_rounded, 'Log out', () async {
            await supabase.auth.signOut();
          }),
        ],
      ),
    );
  }
}

class ItemListScreen extends StatelessWidget {
  final String title;
  final Future<List<Json>> Function() loader;
  final String emptyTitle;
  final String emptyText;
  const ItemListScreen({
    super.key,
    required this.title,
    required this.loader,
    required this.emptyTitle,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<Json>>(
        future: loader(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Loading();
          if (snap.hasError) return ErrorBox(snap.error!);
          final items = snap.data!;
          if (items.isEmpty) {
            return Center(
              child: EmptyState(
                  icon: Icons.inventory_2_outlined, title: emptyTitle, subtitle: emptyText),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
    );
  }
}

class GuidelinesScreen extends StatelessWidget {
  const GuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community guidelines')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text(
            'Lendly is a community-sharing platform. It does not guarantee the safety '
                'or condition of any item. Be kind, return things on time, and meet in '
                'safe, public places.',
            style: TextStyle(fontSize: 15, height: 1.45, color: AppColors.grey),
          ),
          const SectionTitle('Not allowed'),
          FutureBuilder(
            future: supabase.from('prohibited_items').select().order('id'),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Loading();
              if (snap.hasError) return ErrorBox(snap.error!);
              final rows = List<Json>.from(snap.data as List);
              return Column(
                children: [
                  for (final r in rows)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.block_rounded, color: AppColors.red),
                      title: Text(r['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text((r['reason'] ?? '') as String),
                    ),
                ],
              );
            },
          ),
          const SectionTitle('Safe handover tips'),
          const Text(
            '• Meet in a public, well-lit place.\n'
                '• Test the item together and note its condition.\n'
                '• Confirm the handover in the app so both sides have a record.\n'
                '• Never share your exact home address before you both agree.',
            style: TextStyle(fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }
}
