import 'package:flutter/material.dart';

import '../../data/model.dart';
import '../filters/catalog.dart';
import '../format.dart';
import '../theme.dart';

enum PillKind { special, neutral, warning }

/// Etiqueta pequeña, solo informativa (no es un control).
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.kind = PillKind.neutral, this.icon});

  final String label;
  final PillKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      PillKind.special => (AppColors.amber.withValues(alpha: 0.16), AppColors.amber),
      PillKind.neutral => (AppColors.surfaceHighest, AppColors.cream),
      PillKind.warning => (AppColors.error.withValues(alpha: 0.16), AppColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Versión + etiquetas especiales + avisos de un pase.
class SessionBadges extends StatelessWidget {
  const SessionBadges(this.session, {super.key, this.showVersion = true});

  final Session session;
  final bool showVersion;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final version = versionLabel(s.version);
    final special = sortTags(s.tags.where(Session.specialTags.contains));
    final children = [
      if (showVersion && version != null) Pill(version),
      for (final t in special) Pill(capitalize(t), kind: PillKind.special),
      if (s.academicsOnly) const Pill('Solo académicos', kind: PillKind.warning),
      if (s.stale) const Pill('Sin confirmar hoy', kind: PillKind.warning, icon: Icons.history),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 4, children: children);
  }
}

/// Marca ámbar sobre el póster de una película con pases especiales.
class SpecialMark extends StatelessWidget {
  const SpecialMark({super.key, required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final extra = tags.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.amber,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: AppColors.onAmber),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              extra > 0 ? '${capitalize(tags.first)} +$extra' : capitalize(tags.first),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w800, color: AppColors.onAmber),
            ),
          ),
        ],
      ),
    );
  }
}
