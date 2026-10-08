import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data.dart';
import '../theme.dart';
import '../widgets.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _included = TextEditingController();
  final _instructions = TextEditingController();
  final _deposit = TextEditingController(text: '20');
  String _category = 'tools';
  String _condition = 'good';
  String _pickup = 'meet_at_location';
  bool _depositRequired = false;
  bool _busy = false;
  Uint8List? _photo;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _included.dispose();
    _instructions.dispose();
    _deposit.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final x = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (e) {
      if (mounted) toast(context, 'Could not open photos: $e');
    }
  }

  Future<void> _publish() async {
    if (_name.text.trim().isEmpty) {
      toast(context, 'Give your item a name');
      return;
    }
    setState(() => _busy = true);
    try {
      final rnd = Random();
      // Approximate location only: jitter by a few hundred metres for privacy.
      final lat = Me.lat + (rnd.nextDouble() - 0.5) * 0.006;
      final lng = Me.lng + (rnd.nextDouble() - 0.5) * 0.006;
      final created = await supabase
          .from('items')
          .insert({
        'owner_id': Me.id,
        'community_id': Me.communityId,
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'category_id': _category,
        'condition': _condition,
        'pickup_method': _pickup,
        'deposit_amount':
        _depositRequired ? (double.tryParse(_deposit.text) ?? 0) : 0,
        'included': _included.text.trim(),
        'instructions': _instructions.text.trim(),
        'latitude': lat,
        'longitude': lng,
      })
          .select()
          .single();

      final id = created['id'];
      final today = DateTime.now();
      final f = DateFormat('yyyy-MM-dd');
      await supabase.from('item_availability').insert({
        'item_id': id,
        'start_date': f.format(today),
        'end_date': f.format(today.add(const Duration(days: 90))),
      });

      if (_photo != null) {
        final path = '${Me.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('item-images').uploadBinary(
          path,
          _photo!,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        final url = supabase.storage.from('item-images').getPublicUrl(path);
        await supabase
            .from('item_images')
            .insert({'item_id': id, 'url': url, 'sort_order': 0});
      }
      if (mounted) {
        toast(context, 'Your item is now available to your community');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'Could not publish: $e');
      }
    }
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
  );

  Widget _choices(Map<String, String> options, String value, ValueChanged<String> onPick) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in options.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: value == e.key,
              onSelected: (_) => onPick(e.key),
              showCheckmark: false,
              backgroundColor: Colors.white,
              selectedColor: AppColors.greenSoft,
              labelStyle: TextStyle(
                  color: value == e.key ? AppColors.green : AppColors.ink,
                  fontWeight: FontWeight.w600),
              side: BorderSide(color: value == e.key ? AppColors.green : AppColors.line),
              shape: const StadiumBorder(),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lend something')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const Text('What are you lending?',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: _photo == null
                  ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: AppColors.green, size: 32),
                  SizedBox(height: 8),
                  Text('Add a photo', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              )
                  : Image.memory(_photo!, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          _label('Item name'),
          TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'e.g. Cordless drill')),
          _label('Category'),
          _choices(kCategories, _category, (v) => setState(() => _category = v)),
          _label('Description'),
          TextField(
              controller: _desc,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(hintText: 'What is it good for?')),
          _label('Condition'),
          _choices(kConditions, _condition, (v) => setState(() => _condition = v)),
          _label("What's included"),
          TextField(
              controller: _included,
              decoration: const InputDecoration(hintText: 'e.g. 2 batteries, charger')),
          _label('Borrowing instructions'),
          TextField(
              controller: _instructions,
              decoration: const InputDecoration(hintText: 'Anything the borrower should know')),
          _label('Pickup'),
          _choices(kPickups, _pickup, (v) => setState(() => _pickup = v)),
          _label('Deposit'),
          _choices(
            const {'free': 'RM0 · Free to borrow', 'dep': 'Deposit required'},
            _depositRequired ? 'dep' : 'free',
                (v) => setState(() => _depositRequired = v == 'dep'),
          ),
          if (_depositRequired) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _deposit,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: 'RM ', hintText: 'Amount'),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Do not list prohibited items (weapons, hazardous chemicals, drugs and similar). See Community guidelines in Profile.',
            style: TextStyle(color: AppColors.grey, fontSize: 12),
          ),
          const SizedBox(height: 20),
          PillButton(label: 'Publish item', onPressed: _publish, loading: _busy),
        ],
      ),
    );
  }
}
