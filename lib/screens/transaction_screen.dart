import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data.dart';
import '../theme.dart';
import '../widgets.dart';

const _stages = [
  'requested',
  'accepted',
  'handover',
  'borrowed',
  'return_pending',
  'returned',
  'completed',
];

const _stageLabels = {
  'requested': 'Requested',
  'accepted': 'Accepted',
  'handover': 'Handover',
  'borrowed': 'Borrowed',
  'return_pending': 'Return pending',
  'returned': 'Returned',
  'completed': 'Completed',
};

class TransactionScreen extends StatefulWidget {
  final String id;
  const TransactionScreen({super.key, required this.id});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  Json? _tx;
  Json? _handover;
  List<Json> _conditions = [];
  bool _rated = false;
  bool _loading = true;
  bool _busy = false;
  Object? _error;

  final _note = TextEditingController();
  final _code = TextEditingController();
  bool _confirmed = false;
  int _rating = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final tx = await supabase
          .from('transactions')
          .select('*, items(id,name,item_images(url,sort_order)), '
          'borrower:profiles!transactions_borrower_id_fkey(id,name), '
          'owner:profiles!transactions_owner_id_fkey(id,name), '
          'borrow_requests(start_date,return_date,message)')
          .eq('id', widget.id)
          .single();
      final h = await supabase
          .from('handover_records')
          .select()
          .eq('transaction_id', widget.id)
          .order('created_at', ascending: false)
          .limit(1);
      final c = await supabase
          .from('condition_reports')
          .select()
          .eq('transaction_id', widget.id)
          .order('created_at');
      final rated = await supabase
          .from('ratings')
          .select('id')
          .eq('transaction_id', widget.id)
          .eq('rater_id', Me.id);
      if (!mounted) return;
      setState(() {
        _tx = tx;
        _handover = (h as List).isEmpty ? null : Map<String, dynamic>.from(h.first as Map);
        _conditions = List<Json>.from(c);
        _rated = (rated as List).isNotEmpty;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() fn, String done) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (mounted) toast(context, done);
      _note.clear();
      _code.clear();
      _confirmed = false;
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
    if (mounted) setState(() => _busy = false);
    await _load();
  }

  bool get _isOwner => _tx?['owner_id'] == Me.id;
  String get _otherId => (_isOwner ? _tx!['borrower_id'] : _tx!['owner_id']) as String;
  String get _itemName => (_tx?['items'] as Json?)?['name'] ?? 'item';

  Future<void> _setStatus(String status, [Json extra = const {}]) async {
    await supabase
        .from('transactions')
        .update({'status': status, ...extra}).eq('id', widget.id);
  }

  Future<void> _prepareHandover() async {
    final token = (100000 + Random().nextInt(900000)).toString();
    final note = _note.text.trim();
    await supabase.from('condition_reports').insert({
      'transaction_id': widget.id,
      'submitted_by': Me.id,
      'condition_type': 'before_handover',
      'description': note.isEmpty ? 'No visible damage' : note,
    });
    await supabase.from('handover_records').insert({
      'transaction_id': widget.id,
      'kind': 'handover',
      'owner_id': _tx!['owner_id'],
      'borrower_id': _tx!['borrower_id'],
      'qr_token': token,
    });
    await _setStatus('handover');
    await notify(_otherId, 'handover', 'Handover is ready',
        '${Me.firstName} is ready to hand over the $_itemName.');
  }

  Future<void> _confirmHandover(String code) async {
    final rec = _handover;
    if (rec == null || rec['qr_token'] != code.trim()) {
      throw 'That code does not match. Check with the owner.';
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await supabase
        .from('handover_records')
        .update({'confirmed_at': now}).eq('id', rec['id']);
    await _setStatus('borrowed', {'handover_at': now});
    await notify(_otherId, 'handover', 'Handover confirmed',
        '${Me.firstName} confirmed the handover of the $_itemName.');
  }

  Future<void> _scan() async {
    final raw = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (raw == null) return;
    final code = raw.startsWith('lendly:') ? raw.substring(7) : raw;
    setState(() => _code.text = code);
  }

  Future<void> _confirmReturn() async {
    final note = _note.text.trim();
    await supabase.from('condition_reports').insert({
      'transaction_id': widget.id,
      'submitted_by': Me.id,
      'condition_type': 'after_return',
      'description': note.isEmpty ? 'No additional damage' : note,
    });
    await _setStatus('completed', {'return_at': DateTime.now().toUtc().toIso8601String()});
    await notify(_otherId, 'returned', 'Your item has been returned',
        'The $_itemName was returned and the borrow is complete.');
  }

  Future<void> _rate() async {
    await supabase.from('ratings').insert({
      'transaction_id': widget.id,
      'rater_id': Me.id,
      'ratee_id': _otherId,
      'score': _rating,
    });
  }

  Future<void> _reportIssue() async {
    String reason = 'damage';
    final desc = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Report an issue',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                    'The transaction will go under review. Lendly does not decide liability in this prototype.',
                    style: TextStyle(color: AppColors.grey)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in const {
                      'damage': 'Damage',
                      'missing_component': 'Missing component',
                      'late_return': 'Late return',
                      'wrong_item': 'Wrong item',
                      'other': 'Other',
                    }.entries)
                      ChoiceChip(
                        label: Text(e.value),
                        selected: reason == e.key,
                        onSelected: (_) => setS(() => reason = e.key),
                        showCheckmark: false,
                        selectedColor: AppColors.orangeSoft,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                    controller: desc,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'What happened?')),
                const SizedBox(height: 16),
                PillButton(
                    label: 'Submit report', onPressed: () => Navigator.pop(ctx, true)),
              ],
            ),
          ),
        ),
      ),
    );
    final text = desc.text.trim();
    desc.dispose();
    if (ok != true) return;
    await _run(() async {
      await supabase.from('disputes').insert({
        'transaction_id': widget.id,
        'raised_by': Me.id,
        'reason': reason,
        'description': text,
      });
      await _setStatus('under_review');
      await notify(_otherId, 'dispute', 'An issue was reported',
          '${Me.firstName} reported an issue with the $_itemName.');
    }, 'Report submitted. This is now under review.');
  }

  // ---------- UI ----------

  Widget _timeline(String status) {
    final idx = status == 'under_review' ? 4 : _stages.indexOf(status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _stages.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= idx ? AppColors.green : Colors.white,
                        border: Border.all(
                            color: i <= idx ? AppColors.green : AppColors.line, width: 2),
                      ),
                      child: i < idx || (i == idx && status == 'completed')
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    if (i < _stages.length - 1)
                      Container(
                          width: 2,
                          height: 26,
                          color: i < idx ? AppColors.green : AppColors.line),
                  ],
                ),
                const SizedBox(width: 14),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    _stageLabels[_stages[i]]!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: i == idx ? FontWeight.w800 : FontWeight.w500,
                      color: i <= idx ? AppColors.ink : AppColors.grey,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children, Color color = Colors.white}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _noteField(String hint) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: _note,
      maxLines: 2,
      decoration: InputDecoration(hintText: hint),
    ),
  );

  Widget _actions(String status) {
    final owner = _isOwner;
    final borrower = !owner;

    if (status == 'accepted') {
      if (owner) {
        return _card(children: [
          const Text('Before handover',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          const Text('How does the item look? Add a note about its condition.',
              style: TextStyle(color: AppColors.grey)),
          const SizedBox(height: 12),
          _noteField('e.g. Small scratch on handle'),
          PillButton(
              label: 'Prepare handover',
              loading: _busy,
              onPressed: () => _run(_prepareHandover, 'Handover is ready')),
        ]);
      }
      return _card(children: const [
        Text('Waiting for the owner',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        SizedBox(height: 4),
        Text('They will prepare the handover and show you a QR code.',
            style: TextStyle(color: AppColors.grey)),
      ]);
    }

    if (status == 'handover') {
      final before = _conditions.where((c) => c['condition_type'] == 'before_handover');
      final condText = before.isEmpty ? '' : (before.first['description'] ?? '');
      if (owner) {
        final token = _handover?['qr_token'] ?? '';
        return _card(children: [
          const Text('Show this to the borrower',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.line),
              ),
              child: QrImageView(data: 'lendly:$token', size: 200),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('$token',
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 6)),
          ),
          const SizedBox(height: 4),
          const Center(
              child: Text('or read out this code',
                  style: TextStyle(color: AppColors.grey, fontSize: 13))),
          if (condText.toString().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Condition noted: $condText',
                style: const TextStyle(color: AppColors.grey)),
          ],
          const SizedBox(height: 14),
          const Text(
              'Tip: meet somewhere public and well-lit, like a campus entrance or lobby.',
              style: TextStyle(color: AppColors.grey, fontSize: 12)),
        ]);
      }
      return _card(children: [
        const Text('Confirm the handover',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 6),
        if (condText.toString().isNotEmpty)
          Text('Owner noted: $condText', style: const TextStyle(color: AppColors.grey)),
        const SizedBox(height: 14),
        PillButton(label: "Scan owner's QR", secondary: true, onPressed: _scan),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'or enter the 6-digit code'),
        ),
        const SizedBox(height: 10),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.green,
          value: _confirmed,
          onChanged: (v) => setState(() => _confirmed = v ?? false),
          title: const Text('The item matches this condition',
              style: TextStyle(fontSize: 14)),
        ),
        PillButton(
          label: 'Confirm handover',
          loading: _busy,
          onPressed: !_confirmed || _code.text.trim().isEmpty
              ? null
              : () => _run(() => _confirmHandover(_code.text), 'Handover confirmed'),
        ),
      ]);
    }

    if (status == 'borrowed') {
      if (borrower) {
        return _card(children: [
          const Text('Enjoy it, and return it on time',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 12),
          PillButton(
              label: 'Start return',
              loading: _busy,
              onPressed: () => _run(() => _setStatus('return_pending'),
                  'The owner has been notified')),
          const SizedBox(height: 10),
          PillButton(label: 'Report an issue', secondary: true, onPressed: _reportIssue),
        ]);
      }
      return _card(children: const [
        Text('Currently with the borrower',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        SizedBox(height: 4),
        Text('You will be notified when they start the return.',
            style: TextStyle(color: AppColors.grey)),
      ]);
    }

    if (status == 'return_pending') {
      if (owner) {
        return _card(children: [
          const Text('Confirm the return',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          const Text('Check the item and note its condition.',
              style: TextStyle(color: AppColors.grey)),
          const SizedBox(height: 12),
          _noteField('e.g. No additional damage'),
          PillButton(
              label: 'Confirm return',
              loading: _busy,
              onPressed: () => _run(_confirmReturn, 'Return confirmed. All done!')),
          const SizedBox(height: 10),
          PillButton(label: 'Report an issue', secondary: true, onPressed: _reportIssue),
        ]);
      }
      return _card(children: [
        const Text('Waiting for the owner to confirm',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 4),
        const Text('Hand the item back and the owner will confirm the return.',
            style: TextStyle(color: AppColors.grey)),
        const SizedBox(height: 12),
        PillButton(label: 'Report an issue', secondary: true, onPressed: _reportIssue),
      ]);
    }

    if (status == 'completed') {
      return _card(color: AppColors.greenSoft, children: [
        const Row(children: [
          Icon(Icons.check_circle_rounded, color: AppColors.green),
          SizedBox(width: 8),
          Text('Completed',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
        const SizedBox(height: 4),
        const Text('The item is back and the borrow is on both your records.',
            style: TextStyle(color: AppColors.grey)),
        if (!_rated) ...[
          const SizedBox(height: 14),
          const Text('How did it go?', style: TextStyle(fontWeight: FontWeight.w700)),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: AppColors.orange, size: 30),
                ),
            ],
          ),
          PillButton(
              label: 'Submit',
              loading: _busy,
              onPressed: () => _run(_rate, 'Thanks for your feedback')),
        ],
      ]);
    }

    if (status == 'under_review') {
      return _card(color: AppColors.orangeSoft, children: const [
        Text('Under review',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        SizedBox(height: 4),
        Text(
            'An issue was reported. In this prototype a moderator would review the photos and notes from both sides.',
            style: TextStyle(color: AppColors.grey)),
      ]);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Borrowing')),
      body: _loading
          ? const Loading()
          : _error != null
          ? ErrorBox(_error!, onRetry: () {
        setState(() => _loading = true);
        _load();
      })
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final tx = _tx!;
    final item = tx['items'] as Json?;
    final req = tx['borrow_requests'] as Json?;
    final status = tx['status'] as String;
    final f = DateFormat('d MMM');
    final other = (_isOwner ? tx['borrower'] : tx['owner']) as Json?;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
                width: 76,
                height: 76,
                child: ItemImage(url: item == null ? null : firstImage(item))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item?['name'] ?? 'Item',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                Text(_isOwner ? 'Lending to ${other?['name']}' : 'From ${other?['name']}',
                    style: const TextStyle(color: AppColors.grey)),
                if (req != null)
                  Text(
                      '${f.format(DateTime.parse(req['start_date']))} → ${f.format(DateTime.parse(req['return_date']))}',
                      style: const TextStyle(color: AppColors.grey)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 18),
        _timeline(status),
        _actions(status),
        if (_conditions.isNotEmpty)
          _card(children: [
            const Text('Condition record',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 10),
            for (final c in _conditions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${c['condition_type'] == 'before_handover' ? 'Before borrowing' : 'After return'}: ${c['description']}',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
          ]),
      ],
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan owner's QR")),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done || capture.barcodes.isEmpty) return;
          final raw = capture.barcodes.first.rawValue;
          if (raw == null) return;
          _done = true;
          Navigator.pop(context, raw);
        },
      ),
    );
  }
}
