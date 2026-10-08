import 'package:flutter/material.dart';

import '../data.dart';
import '../matching.dart';
import '../theme.dart';
import '../widgets.dart';
import 'item_detail.dart';

class NeedScreen extends StatefulWidget {
  const NeedScreen({super.key});

  @override
  State<NeedScreen> createState() => _NeedScreenState();
}

class _NeedScreenState extends State<NeedScreen> {
  final _ctrl = TextEditingController();
  int? _when; // 0 weekend, 1 tomorrow, 2 next week
  bool _busy = false;
  List<Ranked>? _results;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  DateTimeRange? get _range {
    if (_when == null) return null;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    switch (_when) {
      case 0:
        final sat = today.add(Duration(days: (6 - today.weekday) % 7));
        return DateTimeRange(start: sat, end: sat.add(const Duration(days: 1)));
      case 1:
        final t = today.add(const Duration(days: 1));
        return DateTimeRange(start: t, end: t);
      default:
        final s = today.add(const Duration(days: 7));
        return DateTimeRange(start: s, end: s.add(const Duration(days: 2)));
    }
  }

  Future<void> _find() async {
    if (_ctrl.text.trim().isEmpty) {
      toast(context, 'Tell us what you are trying to do');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final items = (await fetchItems()).where((i) => i['owner_id'] != Me.id).toList();
      final ranked = rankItems(items, _ctrl.text);
      if (mounted) setState(() => _results = ranked);
    } catch (e) {
      if (mounted) toast(context, 'Could not search: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _whenChip(int i, String label) => ChoiceChip(
    label: Text(label),
    selected: _when == i,
    onSelected: (s) => setState(() => _when = s ? i : null),
    showCheckmark: false,
    backgroundColor: Colors.white,
    selectedColor: AppColors.greenSoft,
    labelStyle: TextStyle(
        color: _when == i ? AppColors.green : AppColors.ink,
        fontWeight: FontWeight.w600),
    side: BorderSide(color: _when == i ? AppColors.green : AppColors.line),
    shape: const StadiumBorder(),
  );

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: const Text('I need something')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text('What are you trying to do?',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Describe your goal. We will find things nearby that help.',
              style: TextStyle(color: AppColors.grey, fontSize: 15)),
          const SizedBox(height: 18),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(
                hintText: 'e.g. I need to build a small electronics project this weekend'),
          ),
          const SizedBox(height: 16),
          const Text('When?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _whenChip(0, 'This weekend'),
              _whenChip(1, 'Tomorrow'),
              _whenChip(2, 'Next week'),
            ],
          ),
          const SizedBox(height: 12),
          Text('Where?  ${Me.communityName}',
              style: const TextStyle(color: AppColors.grey)),
          const SizedBox(height: 20),
          PillButton(label: 'Find what I need', onPressed: _find, loading: _busy),
          if (results != null) ...[
            const SizedBox(height: 8),
            if (results.isEmpty)
              const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Nothing matched yet',
                subtitle: 'Try describing it differently, or ask your community.',
              )
            else ...[
              SectionTitle('${results.length} things that could help'),
              for (final r in results)
                ItemCard(
                  item: r.item,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ItemDetailScreen(item: r.item, initialRange: _range),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}