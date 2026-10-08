import 'data.dart';

/// Maps words in a "goal" (e.g. "drill a wall") to item keywords.
const Map<String, List<String>> kIntents = {
  'drill': ['drill'],
  'wall': ['drill'],
  'shelf': ['drill'],
  'screw': ['drill'],
  'hole': ['drill'],
  'camp': ['tent'],
  'tent': ['tent'],
  'sleep': ['tent'],
  'hiking': ['tent'],
  'projector': ['projector'],
  'movie': ['projector', 'speaker'],
  'present': ['projector'],
  'tripod': ['tripod'],
  'camera': ['tripod'],
  'photo': ['tripod'],
  'move': ['trolley', 'table'],
  'moving': ['trolley', 'table'],
  'furniture': ['trolley'],
  'boxes': ['trolley'],
  'house': ['trolley', 'drill'],
  'electronic': ['arduino', 'solder', 'multimeter', 'jumper'],
  'circuit': ['arduino', 'solder', 'multimeter', 'jumper'],
  'project': ['arduino', 'solder', 'multimeter', 'jumper'],
  'arduino': ['arduino', 'jumper'],
  'solder': ['solder'],
  'calculator': ['calculator'],
  'exam': ['calculator'],
  'math': ['calculator'],
  'party': ['speaker', 'table', 'projector'],
  'music': ['speaker'],
  'speaker': ['speaker'],
  'event': ['table', 'speaker', 'projector'],
  'basketball': ['basketball'],
  'ball': ['basketball'],
  'sport': ['basketball'],
  'clean': ['pressure'],
  'wash': ['pressure'],
  'car': ['pressure'],
  'table': ['table'],
};

const _stop = {
  'need', 'the', 'for', 'this', 'that', 'with', 'something', 'some', 'small',
  'build', 'want', 'have', 'help', 'get', 'borrow', 'weekend', 'tomorrow',
  'today', 'next', 'week', 'and', 'from', 'can', 'will', 'use',
};

List<String> _tokens(String q) => q
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z ]'), ' ')
    .split(' ')
    .where((t) => t.length >= 3 && !_stop.contains(t))
    .toList();

Set<String> expandKeywords(String q) {
  final out = <String>{};
  for (final t in _tokens(q)) {
    kIntents.forEach((k, v) {
      if (t == k ||
          (t.length >= 4 && (t.startsWith(k) || k.startsWith(t)))) {
        out.addAll(v);
      }
    });
  }
  return out;
}

class Ranked {
  final Json item;
  final double score;
  final double km;
  Ranked(this.item, this.score, this.km);
}

double _relevance(Json it, List<String> tokens, Set<String> keys) {
  final name = ((it['name'] as String?) ?? '').toLowerCase();
  final text =
  '$name ${(it['description'] ?? '')} ${(it['category_id'] ?? '')}'.toLowerCase();
  double r = 0;
  for (final k in keys) {
    if (name.contains(k)) r = 1.0;
  }
  for (final t in tokens) {
    if (name.contains(t)) {
      r = 1.0;
    } else if (text.contains(t) && r < 0.4) {
      r = 0.4;
    }
  }
  return r;
}

double _conditionScore(String? c) {
  switch (c) {
    case 'like_new':
      return 1.0;
    case 'good':
      return 0.8;
    case 'used':
      return 0.6;
    default:
      return 0.4;
  }
}

/// Ranks by relevance, availability, distance, trust, condition and
/// community proximity (NOT just distance).
List<Ranked> rankItems(List<Json> items, String query) {
  final tokens = _tokens(query);
  final keys = expandKeywords(query);
  final out = <Ranked>[];
  for (final it in items) {
    final km = itemDistance(it);
    final rel = tokens.isEmpty ? 1.0 : _relevance(it, tokens, keys);
    if (tokens.isNotEmpty && rel == 0) continue;
    final owner = (it['profiles'] as Json?) ?? {};
    final score = 0.35 * rel +
        0.20 * (isAvailable(it) ? 1.0 : 0.0) +
        0.15 * (1 / (1 + km / 2)) +
        0.15 * (owner['is_verified'] == true ? 1.0 : 0.4) +
        0.05 * _conditionScore(it['condition'] as String?) +
        0.10 * (it['community_id'] != null && it['community_id'] == Me.communityId ? 1.0 : 0.0);
    out.add(Ranked(it, score, km));
  }
  out.sort((a, b) => b.score.compareTo(a.score));
  return out;
}
