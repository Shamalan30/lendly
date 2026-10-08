import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data.dart';
import '../theme.dart';
import '../widgets.dart';

class ItemDetailScreen extends StatefulWidget {
  final Json item;
  final DateTimeRange? initialRange;
  const ItemDetailScreen({super.key, required this.item, this.initialRange});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  bool _saved = false;
  late final Future<Json> _stats = trustStats(item['owner_id'] as String);

  Json get item => widget.item;
  bool get _mine => item['owner_id'] == Me.id;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final r = await supabase
          .from('saved_items')
          .select()
          .eq('user_id', Me.id)
          .eq('item_id', item['id']);
      if (mounted) setState(() => _saved = (r as List).isNotEmpty);
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    try {
      if (_saved) {
        await supabase
            .from('saved_items')
            .delete()
            .eq('user_id', Me.id)
            .eq('item_id', item['id']);
      } else {
        await supabase
            .from('saved_items')
            .insert({'user_id': Me.id, 'item_id': item['id']});
      }
      if (mounted) setState(() => _saved = !_saved);
    } catch (e) {
      if (mounted) toast(context, 'Could not save: $e');
    }
  }

  Future<void> _request() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _RequestSheet(item: item, initialRange: widget.initialRange),
    );
    if (sent == true && mounted) {
      toast(context, 'Request sent. We will let you know when they reply.');
      Navigator.pop(context);
    }
  }

  Widget _section(String title, String? text) {
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(text,
              style: const TextStyle(color: AppColors.grey, fontSize: 15, height: 1.4)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final owner = (item['profiles'] as Json?) ?? {};
    final images = allImages(item);
    final km = itemDistance(item);
    final available = isAvailable(item);

    String cta = 'Request to borrow';
    if (_mine) cta = 'This is your item';
    if (!_mine && !available) cta = 'Currently on loan';

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
            onPressed: _toggleSave,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SizedBox(
              height: 280,
              child: images.isEmpty
                  ? const ItemImage(url: null)
                  : PageView(children: [for (final u in images) ItemImage(url: u)]),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(item['name'] ?? '',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              ),
              isFree(item)
                  ? const Pill('Free')
                  : Pill(priceLabel(item),
                  bg: AppColors.orangeSoft, fg: AppColors.orange),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${distanceLabel(km)}  ·  ${available ? 'Available today' : 'On loan right now'}',
            style: const TextStyle(color: AppColors.grey, fontSize: 15),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.line),
            ),
            child: FutureBuilder<Json>(
              future: _stats,
              builder: (context, snap) {
                final s = snap.data ?? {};
                final lent = (s['items_lent'] as num?)?.toInt() ?? 0;
                final rate = (s['return_rate'] as num?)?.toInt() ?? 100;
                final trusted = lent >= 3 || owner['is_verified'] == true;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Avatar(
                            name: owner['name'] as String?,
                            url: owner['profile_image'] as String?,
                            radius: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(owner['name'] ?? 'Neighbour',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 17)),
                              Text(trusted ? 'Trusted lender' : 'New lender',
                                  style: const TextStyle(color: AppColors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (owner['is_verified'] == true) const Pill('Identity verified'),
                        Pill('$lent successful lends'),
                        Pill('$rate% return rate'),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          _section('What is it?', item['description'] as String?),
          _section('Condition', kConditions[item['condition']] ?? ''),
          _section('Included', item['included'] as String?),
          _section('Borrowing instructions', item['instructions'] as String?),
          _section('Pickup', kPickups[item['pickup_method']] ?? ''),
          _section('Availability', available ? 'Available now' : 'Currently on loan'),
          _section('Please note',
              'Lendly is a community-sharing platform. It does not guarantee the safety or condition of any item. The exact pickup spot is agreed after your request is accepted.'),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: PillButton(
            label: cta,
            onPressed: (_mine || !available) ? null : _request,
          ),
        ),
      ),
    );
  }
}

class _RequestSheet extends StatefulWidget {
  final Json item;
  final DateTimeRange? initialRange;
  const _RequestSheet({required this.item, this.initialRange});

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  late DateTimeRange _range;
  final _msg = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    _range = widget.initialRange ??
        DateTimeRange(start: today, end: today.add(const Duration(days: 1)));
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final r = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 120)),
      initialDateRange: _range.start.isBefore(today) ? null : _range,
    );
    if (r != null) setState(() => _range = r);
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final f = DateFormat('yyyy-MM-dd');
      await supabase.from('borrow_requests').insert({
        'item_id': widget.item['id'],
        'borrower_id': Me.id,
        'owner_id': widget.item['owner_id'],
        'start_date': f.format(_range.start),
        'return_date': f.format(_range.end),
        'message': _msg.text.trim(),
      });
      await notify(widget.item['owner_id'] as String, 'request', 'New borrowing request',
          '${Me.firstName} would like to borrow your ${widget.item['name']}.');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'Could not send request: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('EEE, d MMM');
    final days = _range.end.difference(_range.start).inDays + 1;
    final dep = depositOf(widget.item);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.line, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            Text('Borrow ${widget.item['name']}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _pick,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppColors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('${f.format(_range.start)}  →  ${f.format(_range.end)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msg,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                hintText:
                'Hi ${(widget.item['profiles'] as Json?)?['name'] ?? ''}, I need this for...',
              ),
            ),
            const SizedBox(height: 18),
            _row('Borrow period', '$days ${days == 1 ? 'day' : 'days'}'),
            _row('Deposit', 'RM${dep.toStringAsFixed(0)}'),
            _row('Total', dep == 0 ? 'Free' : 'RM${dep.toStringAsFixed(0)} deposit',
                bold: true),
            const SizedBox(height: 18),
            PillButton(label: 'Send request', onPressed: _send, loading: _busy),
          ],
        ),
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(a, style: const TextStyle(color: AppColors.grey)),
        Text(b,
            style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontSize: bold ? 17 : 15)),
      ],
    ),
  );
}
