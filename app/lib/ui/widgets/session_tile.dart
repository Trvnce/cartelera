import 'package:flutter/material.dart';

import '../../data/model.dart';
import '../format.dart';
import '../theme.dart';
import 'badges.dart';
import 'poster.dart';

/// Fila de la agenda: hora, miniatura, título, cine · sala, etiquetas y precio.
class SessionTile extends StatelessWidget {
  const SessionTile({super.key, required this.session, required this.onTap});

  final Session session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final place = [s.cinema, if (s.room != null && s.room!.isNotEmpty) s.room!].join(' · ');
    final price = fmtPrice(s.priceEur);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 54,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    fmtTime(s.start),
                    textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: s.isSpecial ? AppColors.amber : AppColors.cream,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 44,
                  height: 66,
                  child: Poster(url: s.poster, title: s.title, cacheWidth: 132, compact: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, height: 1.25, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.35, color: AppColors.muted),
                    ),
                    if (s.cycle != null && s.cycle!.trim().isNotEmpty)
                      Text(
                        s.cycle!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.amber),
                      ),
                    Padding(padding: const EdgeInsets.only(top: 5), child: SessionBadges(s)),
                  ],
                ),
              ),
              if (price != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    price,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: s.priceEur == 0 ? AppColors.ok : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
