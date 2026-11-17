import 'package:flutter/material.dart';

import '../adaptive.dart';
import '../../data/model.dart';
import '../app_model.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/open_url.dart';

/// Estado de cada web leída: si ha ido bien, cuántos pases ha dado y el enlace.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key, required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final repo = model.repo;
        final snap = repo.snapshot;
        final p = repo.progress;
        final now = model.now;
        final finished = {for (final s in p?.finished ?? const <SourceStatus>[]) s.id: s};
        final known = snap?.sources ?? const <SourceStatus>[];
        // Durante una actualización manda lo recién leído; el resto, lo anterior.
        final rows = <SourceStatus>[
          for (final s in known) finished[s.id] ?? s,
          for (final s in finished.values)
            if (!known.any((k) => k.id == s.id)) s,
        ];
        final failed = rows.where((s) => !s.ok).length;
        return Scaffold(
          appBar: adaptiveBar(
            context,
            title: 'Fuentes',
            leading: isCupertino(context)
                ? null
                : IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Atrás', onPressed: () => Navigator.of(context).pop()),
          ),
          body: ListView(
            padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p != null
                              ? 'Actualizando… ${p.total > 1 ? '${p.done} de ${p.total}' : ''}'
                              : snap == null
                                  ? 'Todavía no se ha leído la cartelera'
                                  : 'Actualizada ${fmtUpdated(snap.generatedAt, now)}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'La app lee la web de cada cine desde este móvil. '
                          '${snap == null ? '' : '${plural(snap.sessions.length, 'pase leído', 'pases leídos')} de '
                              '${plural(known.length, 'fuente', 'fuentes')}.'}',
                          style: const TextStyle(fontSize: 14, height: 1.35, color: AppColors.muted),
                        ),
                        if (p != null) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(value: p.done == 0 ? null : p.fraction, minHeight: 4),
                        ],
                        if (repo.lastError != null && p == null) ...[
                          const SizedBox(height: 12),
                          _Warning(icon: Icons.error_outline, color: AppColors.error, text: repo.lastError!),
                        ],
                        if (model.staleCount > 0) ...[
                          const SizedBox(height: 12),
                          _Warning(
                            icon: Icons.history,
                            color: AppColors.amber,
                            text: '${plural(model.staleCount, 'pase se muestra', 'pases se muestran')} con datos de la '
                                'última lectura buena porque su web ha fallado. Van marcados como «Sin confirmar hoy».',
                          ),
                        ] else if (failed > 0 && p == null) ...[
                          const SizedBox(height: 12),
                          _Warning(
                            icon: Icons.warning_amber_rounded,
                            color: AppColors.amber,
                            text: '${plural(failed, 'fuente ha fallado', 'fuentes han fallado')} en la última lectura.',
                          ),
                        ],
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: repo.refreshing ? null : repo.refresh,
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          icon: const Icon(Icons.refresh),
                          label: Text(repo.refreshing ? 'Actualizando…' : 'Actualizar ahora'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (rows.isEmpty && p == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Aún no hay fuentes leídas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              for (final s in rows)
                _SourceTile(
                  status: s,
                  now: now,
                  running: p != null && p.running.contains(s.name),
                  pending: p != null && !finished.containsKey(s.id),
                ),
              // Fuentes en curso que todavía no conocemos de lecturas anteriores.
              if (p != null)
                for (final name in p.running)
                  if (!rows.any((r) => r.name == name))
                    ListTile(
                      leading: const _Spinner(),
                      title: Text(name),
                      subtitle: const Text('Leyendo…'),
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 24,
        height: 24,
        child: Padding(padding: EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
}

class _Warning extends StatelessWidget {
  const _Warning({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.35))),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.status, required this.now, required this.running, required this.pending});
  final SourceStatus status;
  final DateTime now;
  final bool running;

  /// Hay una actualización en marcha y a esta fuente aún no le ha tocado:
  /// lo que se enseña es de la lectura anterior.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final Widget leading = running
        ? const _Spinner()
        : Icon(
            s.ok ? Icons.check_circle_rounded : Icons.error_rounded,
            color: (s.ok ? AppColors.ok : AppColors.error).withValues(alpha: pending ? 0.45 : 1),
          );
    final when = 'leída ${fmtUpdated(s.at, now)}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: leading,
      title: Text(s.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            running
                ? 'Leyendo…'
                : s.ok
                    ? '${plural(s.count, 'pase', 'pases')} · $when'
                    : 'Ha fallado · $when',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          if (!s.ok && s.error != null && s.error!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                s.error!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.open_in_new, size: 20, color: AppColors.muted),
      onTap: () => openUrl(context, s.url),
    );
  }
}
