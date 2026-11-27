import 'package:flutter/material.dart';

import '../app_model.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/session_tile.dart';
import 'home_screen.dart' show EmptyResults;

/// Agenda: todos los pases por orden de hora, con la cabecera del día fija
/// arriba mientras se recorre ese día.
class AgendaView extends StatelessWidget {
  const AgendaView({super.key, required this.model, required this.onOpenFilm, required this.onRefresh});

  final AppModel model;
  final ValueChanged<String> onOpenFilm;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final days = model.days;
    final now = model.now;
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: days.isEmpty
          ? EmptyResults(model: model)
          : CustomScrollView(
              key: const PageStorageKey('agenda'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                for (final g in days)
                  SliverMainAxisGroup(
                    slivers: [
                      PinnedHeaderSliver(child: DayHeader(day: g.day, now: now, count: g.sessions.length)),
                      SliverList.separated(
                        itemCount: g.sessions.length,
                        separatorBuilder: (_, _) => const Divider(indent: 70),
                        itemBuilder: (context, i) {
                          final s = g.sessions[i];
                          return SessionTile(session: s, onTap: () => onOpenFilm(s.filmKey));
                        },
                      ),
                    ],
                  ),
                // + lo que tape la barra de pestañas flotante (iOS nativo).
                SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
              ],
            ),
    );
  }
}

/// Cabecera de día: «Hoy · martes 17 de noviembre», «Jueves 19 de noviembre».
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.day, required this.now, this.count});

  final DateTime day;
  final DateTime now;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // Con letra grande en un móvil estrecho no cabe todo: el día se recorta antes que
          // desbordar, y se queda con casi todo el sitio frente al subtítulo.
          Flexible(
            flex: 4,
            child: Text(
              fmtDayTitle(day, now),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fmtDaySubtitle(day, now),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppColors.muted),
            ),
          ),
          if (count != null)
            Text(plural(count!, 'pase', 'pases'), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
      ),
    );
  }
}
