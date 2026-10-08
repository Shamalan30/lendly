import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
typedef Json = Map<String, dynamic>;

const kItemSelect =
    '*, item_images(url,sort_order), profiles!items_owner_id_fkey(id,name,profile_image,is_verified)';

const kCategories = <String, String>{
  'tools': 'Tools',
  'electronics': 'Electronics',
  'study': 'Study',
  'sports': 'Sports',
  'camping': 'Camping',
  'events': 'Events',
  'kitchen': 'Kitchen',
  'books': 'Books',
  'games': 'Games',
  'other': 'Other',
};

const kCategoryIcons = <String, IconData>{
  'tools': Icons.hardware_rounded,
  'electronics': Icons.memory_rounded,
  'study': Icons.menu_book_rounded,
  'sports': Icons.sports_basketball_rounded,
  'camping': Icons.cabin_rounded,
  'events': Icons.celebration_rounded,
  'kitchen': Icons.kitchen_rounded,
  'books': Icons.auto_stories_rounded,
  'games': Icons.sports_esports_rounded,
  'other': Icons.category_rounded,
};

const kConditions = <String, String>{
  'like_new': 'Like new',
  'good': 'Good',
  'used': 'Used',
  'well_used': 'Well used',
};

const kPickups = <String, String>{
  'meet_at_location': 'Meet at a location',
  'pickup_from_me': 'Pickup from me',
  'other': 'Other agreed location',
};

/// The signed-in user's profile + community, cached for the session.
class Me {
  static Json? profile;
  static Json? community;
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static String get id => supabase.auth.currentUser!.id;
  static String? get communityId => profile?['community_id'] as String?;
  static String get communityName =>
      (community?['name'] as String?) ?? 'your community';

  static String get firstName {
    final n = ((profile?['name'] as String?) ?? '').trim();
    return n.isEmpty ? 'there' : n.split(' ').first;
  }

  static double get lat =>
      ((profile?['location_latitude'] ?? community?['latitude']) as num?)
          ?.toDouble() ??
          3.1729;
  static double get lng =>
      ((profile?['location_longitude'] ?? community?['longitude']) as num?)
          ?.toDouble() ??
          101.7283;

  static Future<void> load() async {
    final p = await supabase
        .from('profiles')
        .select('*, communities(id,name,latitude,longitude)')
        .eq('id', id)
        .single();
    profile = p;
    community = p['communities'] as Json?;
  }
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  return 2 * 6371.0 * asin(sqrt(a));
}

double itemDistance(Json item) {
  final la = (item['latitude'] as num?)?.toDouble();
  final lo = (item['longitude'] as num?)?.toDouble();
  if (la == null || lo == null) return 99;
  return distanceKm(Me.lat, Me.lng, la, lo);
}

String distanceLabel(double km) => km >= 99
    ? 'Nearby'
    : km < 1
    ? '${(km * 1000).round()} m away'
    : '${km.toStringAsFixed(1)} km away';

List<String> allImages(Json item) {
  final imgs = List<Json>.from((item['item_images'] as List?) ?? []);
  imgs.sort((a, b) => ((a['sort_order'] ?? 0) as int)
      .compareTo((b['sort_order'] ?? 0) as int));
  return imgs.map((e) => e['url'] as String).toList();
}

String? firstImage(Json item) {
  final l = allImages(item);
  return l.isEmpty ? null : l.first;
}

double depositOf(Json item) => ((item['deposit_amount'] as num?) ?? 0).toDouble();
bool isFree(Json item) => depositOf(item) == 0;
String priceLabel(Json item) =>
    isFree(item) ? 'Free' : 'RM${depositOf(item).toStringAsFixed(0)} deposit';
bool isAvailable(Json item) => item['status'] == 'available';

Future<List<Json>> fetchItems() async {
  final res = await supabase
      .from('items')
      .select(kItemSelect)
      .order('created_at', ascending: false);
  return List<Json>.from(res);
}

Future<Json?> fetchImpact() async {
  try {
    final r = await supabase.rpc('get_impact_stats');
    if (r is List && r.isNotEmpty) return Map<String, dynamic>.from(r.first as Map);
    if (r is Map) return Map<String, dynamic>.from(r);
  } catch (_) {}
  return null;
}

Future<Json> trustStats(String uid) async {
  try {
    final r = await supabase.rpc('get_trust_stats', params: {'uid': uid});
    if (r is List && r.isNotEmpty) return Map<String, dynamic>.from(r.first as Map);
    if (r is Map) return Map<String, dynamic>.from(r);
  } catch (_) {}
  return {};
}

Future<void> notify(String userId, String type, String title, String body) async {
  try {
    await supabase.from('notifications').insert({
      'user_id': userId,
      'type': type,
      'title': title,
      'body': body,
    });
  } catch (_) {}
}
