import 'package:flutter/material.dart';
import 'data.dart';
import 'theme.dart';

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
}

class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool danger;
  final bool loading;
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.danger = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = secondary ? Colors.white : (danger ? AppColors.red : AppColors.green);
    final fg = secondary ? AppColors.ink : Colors.white;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: secondary ? Colors.white : AppColors.line,
          elevation: 0,
          shape: StadiumBorder(
            side: secondary ? const BorderSide(color: AppColors.line) : BorderSide.none,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: loading
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: fg),
        )
            : Text(label),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String? name;
  final String? url;
  final double radius;
  const Avatar({super.key, this.name, this.url, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final initial = (name ?? '?').trim().isEmpty ? '?' : name!.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.greenSoft,
      backgroundImage: (url != null && url!.isNotEmpty) ? NetworkImage(url!) : null,
      child: (url != null && url!.isNotEmpty)
          ? null
          : Text(initial,
          style: TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w700,
              fontSize: radius * 0.9)),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const Pill(this.text,
      {super.key, this.bg = AppColors.greenSoft, this.fg = AppColors.green});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

class ItemImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  const ItemImage({super.key, this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
      color: AppColors.greenSoft,
      alignment: Alignment.center,
      child: const Icon(Icons.inventory_2_outlined, color: AppColors.green, size: 36),
    );
    if (url == null) return placeholder();
    return Image.network(
      url!,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => placeholder(),
      loadingBuilder: (c, child, p) => p == null
          ? child
          : Container(color: AppColors.line.withAlpha(120)),
    );
  }
}

class ItemCard extends StatelessWidget {
  final Json item;
  final VoidCallback onTap;
  const ItemCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final owner = (item['profiles'] as Json?) ?? {};
    final km = itemDistance(item);
    final available = isAvailable(item);
    final isMine = item['owner_id'] == Me.id;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.line),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: ItemImage(url: firstImage(item)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item['name'] ?? '',
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w700)),
                      ),
                      isFree(item)
                          ? const Pill('Free')
                          : Pill(priceLabel(item),
                          bg: AppColors.orangeSoft, fg: AppColors.orange),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${distanceLabel(km)}  ·  ${available ? 'Available today' : 'On loan'}',
                    style: const TextStyle(color: AppColors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Avatar(
                          name: owner['name'] as String?,
                          url: owner['profile_image'] as String?,
                          radius: 13),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${owner['name'] ?? 'Neighbour'}'
                              '${owner['is_verified'] == true ? ' · Trusted lender' : ''}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.ink),
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 8),
                        const Pill('Yours'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyState(
      {super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
              color: AppColors.greenSoft, shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.green, size: 32),
        ),
        const SizedBox(height: 18),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grey, fontSize: 15)),
      ],
    ),
  );
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(48),
    child: Center(child: CircularProgressIndicator(color: AppColors.green)),
  );
}

class ErrorBox extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorBox(this.error, {super.key, this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_rounded, color: AppColors.grey, size: 40),
        const SizedBox(height: 12),
        Text('$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grey)),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(text,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
  );
}