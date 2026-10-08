import 'package:flutter/material.dart';

import '../data.dart';
import '../matching.dart';
import '../theme.dart';
import '../widgets.dart';
import 'item_detail.dart';

/// Wrapper so Explore can be pushed as its own page (e.g. from a category chip).
class ExploreScreen extends StatelessWidget {
  final String? initialCategory;
  const ExploreScreen({super.key, this.initialCategory});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Explore')),
    body: ExploreTab(initialCategory: initialCategory),
  );
}

class ExploreTab extends StatefulWidget {
  final String? initialCategory;
  const ExploreTab({super.key, this.initialCategory});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  late Future<List<Json>> _items = fetchItems();
  final _search = TextEditingController();
  String _query = '';
  String? _category;
  bool _freeOnly = false;
  bool _availableNow = false;
  bool _myCommunity = false;
  bool _trusted = false;
  double? _radius;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: AppColors.greenSoft,
      labelStyle: TextStyle(
        color: selected ? AppColors.green : AppColors.ink,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      side: BorderSide(color: selected ? AppColors.green : AppColors.line),
      shape: const StadiumBorder(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Try "something to drill a wall"',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: AppColors.line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: AppColors.line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: AppColors.green)),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _chip('Free only', _freeOnly, () => setState(() => _freeOnly = !_freeOnly)),
              _chip('Available now', _availableNow,
                      () => setState(() => _availableNow = !_availableNow)),
              _chip('My community', _myCommunity,
                      () => setState(() => _myCommunity = !_myCommunity)),
              _chip('Trusted lenders', _trusted, () => setState(() => _trusted = !_trusted)),
              for (final r in [1.0, 5.0, 10.0])
                _chip('Within ${r.toInt()} km', _radius == r,
                        () => setState(() => _radius = _radius == r ? null : r)),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _chip('All', _category == null, () => setState(() => _category = null)),
              for (final e in kCategories.entries)
                _chip(e.value, _category == e.key,
                        () => setState(() => _category = _category == e.key ? null : e.key)),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.green,
            onRefresh: () async {
              setState(() => _items = fetchItems());
              await _items;
            },
            child: FutureBuilder<List<Json>>(
              future: _items,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return ListView(children: const [Loading()]);
                }
                if (snap.hasError) {
                  return ListView(children: [
                    ErrorBox(snap.error!,
                        onRetry: () => setState(() => _items = fetchItems()))
                  ]);
                }
                var items = snap.data!.toList();
                if (_category != null) {
                  items = items.where((i) => i['category_id'] == _category).toList();
                }
                if (_freeOnly) items = items.where(isFree).toList();
                if (_availableNow) items = items.where(isAvailable).toList();
                if (_myCommunity) {
                  items = items
                      .where((i) => i['community_id'] == Me.communityId)
                      .toList();
                }
                if (_trusted) {
                  items = items
                      .where((i) =>
                  ((i['profiles'] as Json?)?['is_verified'] ?? false) == true)
                      .toList();
                }
                if (_radius != null) {
                  items = items.where((i) => itemDistance(i) <= _radius!).toList();
                }
                final ranked = rankItems(items, _query);
                if (ranked.isEmpty) {
                  return ListView(children: const [
                    EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Nothing matches yet',
                      subtitle: 'Try different words, or widen your filters.',
                    ),
                  ]);
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    for (final r in ranked)
                      ItemCard(
                        item: r.item,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ItemDetailScreen(item: r.item)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
