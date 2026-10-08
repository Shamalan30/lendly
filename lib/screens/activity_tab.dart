import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'item_detail.dart';
import 'transaction_screen.dart';

const _txSelect =
    '*, items(id,name,item_images(url,sort_order)), '
    'borrower:profiles!transactions_borrower_id_fkey(id,name), '
    'owner:profiles!transactions_owner_id_fkey(id,name)';

const _reqSelect =
    '*, items(id,name,item_images(url,sort_order)), '
    'borrower:profiles!borrow_requests_borrower_id_fkey(id,name,is_verified), '
    'owner:profiles!borrow_requests_owner_id_fkey(id,name)';

String statusLabel(String s) {
  switch (s) {
    case 'requested':
      return 'Requested';
    case 'accepted':
      return 'Accepted';
    case 'handover':
      return 'Handover';
    case 'borrowed':
      return 'Borrowed';
    case 'return_pending':
      return 'Return pending';
    case 'returned':
      return 'Returned';
    case 'completed':
      return 'Completed';
    case 'under_review':
      return 'Under review';
    case 'declined':
      return 'Declined';
    default:
      return s;
  }
}

class ActivityTab extends StatefulWidget {
  const ActivityTab({super.key});

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  late Future<List<List<Json>>> _data = _load();

  // Returns: [borrowing, lending, incoming requests, outgoing requests, my listings]
  Future<List<List<Json>>> _load() async {
    final borrowing = await supabase
        .from('transactions')
        .select(_txSelect)
        .eq('borrower_id', Me.id)
        .order('created_at', ascending: false);
    final lending = await supabase
        .from('transactions')
        .select(_txSelect)
        .eq('owner_id', Me.id)
        .order('created_at', ascending: false);
    final incoming = await supabase
        .from('borrow_requests')
        .select(_reqSelect)
        .eq('owner_id', Me.id)
        .eq('status', 'requested')
        .order('created_at', ascending: false);
    final outgoing = await supabase
        .from('borrow_requests')
        .select(_reqSelect)
        .eq('borrower_id', Me.id)
        .inFilter('status', ['requested', 'declined'])
        .order('created_at', ascending: false);
    final mine = await supabase
        .from('items')
        .select(kItemSelect)
        .eq('owner_id', Me.id)
        .order('created_at', ascending: false);
    return [
      List<Json>.from(borrowing),
      List<Json>.from(lending),
      List<Json>.from(incoming),
      List<Json>.from(outgoing),
      List<Json>.from(mine),
    ];
  }

  Future<void> _refresh() async {
    setState(() => _data = _load());
    await _data;
  }

  Future<void> _answer(Json r, bool accept) async {
    try {
      await supabase
          .from('borrow_requests')
          .update({'status': accept ? 'accepted' : 'declined'}).eq('id', r['id']);
      if (accept) {
        await supabase.from('transactions').insert({
          'borrow_request_id': r['id'],
          'item_id': r['item_id'],
          'borrower_id': r['borrower_id'],
          'owner_id': r['owner_id'],
          'status': 'accepted',
        });
      }
      final itemName = (r['items'] as Json?)?['name'] ?? 'item';
      await notify(
        r['borrower_id'] as String,
        accept ? 'accepted' : 'declined',
        accept ? 'Your borrowing request was accepted' : 'Your request was declined',
        accept
            ? '${Me.firstName} accepted your request for the $itemName.'
            : '${Me.firstName} could not lend the $itemName this time.',
      );
      if (mounted) {
        toast(context, accept ? 'Accepted. Handover is next.' : 'Request declined');
      }
    } catch (e) {
      if (mounted) toast(context, 'Something went wrong: $e');
    }
    await _refresh();
  }

  Future<void> _openTx(Json t) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => TransactionScreen(id: t['id'] as String)));
    _refresh();
  }

  Widget _thumb(Json? item) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
        width: 64,
        height: 64,
        child: ItemImage(url: item == null ? null : firstImage(item))),
  );

  Widget _statusPill(String s) {
    final warn = s == 'under_review' || s == 'return_pending';
    final bad = s == 'declined';
    return Pill(
      statusLabel(s),
      bg: bad ? AppColors.redSoft : (warn ? AppColors.orangeSoft : AppColors.greenSoft),
      fg: bad ? AppColors.red : (warn ? AppColors.orange : AppColors.green),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 10),
    child: Text(text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
  );

  Widget _listingCard(Json it) {
    final available = isAvailable(it);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ItemDetailScreen(item: it)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            _thumb(it),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it['name'] ?? 'Item',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(priceLabel(it), style: const TextStyle(color: AppColors.grey)),
                  const SizedBox(height: 6),
                  available
                      ? const Pill('Listed · Available')
                      : const Pill('On loan',
                      bg: AppColors.orangeSoft, fg: AppColors.orange),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
          ],
        ),
      ),
    );
  }

  Widget _txCard(Json t, {required bool borrowing}) {
    final item = t['items'] as Json?;
    final other = (borrowing ? t['owner'] : t['borrower']) as Json?;
    return GestureDetector(
      onTap: () => _openTx(t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            _thumb(item),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item?['name'] ?? 'Item',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                      borrowing
                          ? 'From ${other?['name'] ?? ''}'
                          : 'To ${other?['name'] ?? ''}',
                      style: const TextStyle(color: AppColors.grey)),
                  const SizedBox(height: 6),
                  _statusPill(t['status'] as String),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
          ],
        ),
      ),
    );
  }

  Widget _incomingCard(Json r) {
    final item = r['items'] as Json?;
    final b = r['borrower'] as Json?;
    final f = DateFormat('d MMM');
    final msg = (r['message'] as String?) ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New borrowing request',
              style: TextStyle(
                  color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          Row(children: [
            _thumb(item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item?['name'] ?? 'Item',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  Text(
                      '${f.format(DateTime.parse(r['start_date']))} → ${f.format(DateTime.parse(r['return_date']))}',
                      style: const TextStyle(color: AppColors.grey)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Avatar(name: b?['name'] as String?, radius: 14),
            const SizedBox(width: 8),
            Text(b?['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (b?['is_verified'] == true) ...[
              const SizedBox(width: 8),
              const Pill('Verified'),
            ],
          ]),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('"$msg"',
                style: const TextStyle(color: AppColors.grey, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: PillButton(
                    label: 'Decline', secondary: true, onPressed: () => _answer(r, false))),
            const SizedBox(width: 10),
            Expanded(child: PillButton(label: 'Accept', onPressed: () => _answer(r, true))),
          ]),
        ],
      ),
    );
  }

  Widget _outgoingCard(Json r) {
    final item = r['items'] as Json?;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        _thumb(item),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item?['name'] ?? 'Item',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text('Asked ${(r['owner'] as Json?)?['name'] ?? ''}',
                  style: const TextStyle(color: AppColors.grey)),
              const SizedBox(height: 6),
              _statusPill(r['status'] == 'requested' ? 'requested' : 'declined'),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _list(List<Widget> children, Widget empty) => RefreshIndicator(
    color: AppColors.green,
    onRefresh: _refresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: children.isEmpty ? [empty] : children,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Activity',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
            ),
          ),
          const TabBar(
            labelColor: AppColors.green,
            unselectedLabelColor: AppColors.grey,
            indicatorColor: AppColors.green,
            tabs: [Tab(text: 'Borrowing'), Tab(text: 'Lending'), Tab(text: 'Requests')],
          ),
          Expanded(
            child: FutureBuilder<List<List<Json>>>(
              future: _data,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Loading();
                if (snap.hasError) return ErrorBox(snap.error!, onRetry: _refresh);
                final d = snap.data!;
                return TabBarView(
                  children: [
                    _list(
                      [for (final t in d[0]) _txCard(t, borrowing: true)],
                      const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No borrowing yet',
                        subtitle: 'Your next borrowed item could be closer than you think.',
                      ),
                    ),
                    _list(
                      [
                        if (d[4].isNotEmpty) _heading('Your listings'),
                        for (final it in d[4]) _listingCard(it),
                        if (d[1].isNotEmpty) _heading('Lending activity'),
                        for (final t in d[1]) _txCard(t, borrowing: false),
                      ],
                      const EmptyState(
                        icon: Icons.volunteer_activism_outlined,
                        title: 'No lending yet',
                        subtitle: 'Your unused things could help someone nearby.',
                      ),
                    ),
                    _list(
                      [
                        for (final r in d[2]) _incomingCard(r),
                        if (d[3].isNotEmpty) _heading('Your requests'),
                        for (final r in d[3]) _outgoingCard(r),
                      ],
                      const EmptyState(
                        icon: Icons.mark_email_unread_outlined,
                        title: 'No requests',
                        subtitle: 'Requests to borrow your things will appear here.',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}