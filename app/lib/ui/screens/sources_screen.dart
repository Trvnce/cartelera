import 'package:flutter/material.dart';

import '../adaptive.dart';
import '../../data/engine.dart' show allSources;
import '../../data/model.dart';
import '../app_model.dart';
import '../format.dart';
import '../theme.dart';
import '../update_prompt.dart';
import '../../data/updater.dart';
import '../widgets/open_url.dart';

/// Las fuentes: cada web con su interruptor (las desactivadas no se leen y sus pases no
/// salen), si ha ido bien en la última lectura, cuántos pases ha dado y su enlace.
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
        final known = {for (final s in snap?.sources ?? const <SourceStatus>[]) s.id: s};
        // Durante una actualización manda lo recién leído; el resto, lo anterior.
        final rows = [for (final src in allSources) (src: src, status: finished[src.id] ?? known[src.id])];
        final enabledCount = model.enabledSources.length;
        final failed = rows.where((r) => model.isSourceEnabled(r.src.id) && r.status != null && !r.status!.ok).length;
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
                              '${plural(enabledCount, 'fuente activada', 'fuentes activadas')}.'}',
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
                          onPressed: repo.refreshing ? null : model.refresh,
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          icon: const Icon(Icons.refresh),
                          label: Text(repo.refreshing ? 'Actualizando…' : 'Actualizar ahora'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Desactiva las que no te interesen: no se leen al actualizar y sus pases dejan de salir.',
                  style: TextStyle(fontSize: 13.5, height: 1.35, color: AppColors.muted),
                ),
              ),
              for (final r in rows)
                _SourceTile(
                  name: r.src.name,
                  url: r.src.url,
                  status: r.status,
                  enabled: model.isSourceEnabled(r.src.id),
                  // La última activada no se puede apagar: la cartelera se quedaría vacía.
                  locked: model.isSourceEnabled(r.src.id) && enabledCount <= 1,
                  onChanged: (v) => model.setSourceEnabled(r.src.id, v),
                  now: now,
                  running: p != null && p.running.contains(r.src.name),
                  pending: p != null && !finished.containsKey(r.src.id),
                ),
              if (Updater.supported) const _AppVersion(),
            ],
          ),
        );
      },
    );
  }
}

/// Pie de la lista: versión instalada y «Buscar actualizaciones» (GitHub Releases).
class _AppVersion extends StatelessWidget {
  const _AppVersion();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<String>(
              future: Updater.installedVersion(),
              builder: (_, v) => Text(
                v.hasData ? 'Cartelera ${v.data}' : 'Cartelera',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => checkForUpdateNow(context),
            icon: const Icon(Icons.system_update_outlined, size: 18),
            label: const Text('Buscar actualizaciones'),
          ),
        ],
      ),
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
  const _SourceTile({
    required this.name,
    required this.url,
    required this.status,
    required this.enabled,
    required this.locked,
    required this.onChanged,
    required this.now,
    required this.running,
    required this.pending,
  });
  final String name;
  final String url;

  /// Última lectura de la fuente (null si no se ha leído nunca o se desactivó).
  final SourceStatus? status;
  final bool enabled;
  final bool locked;
  final ValueChanged<bool> onChanged;
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
        : !enabled || s == null
            ? Icon(enabled ? Icons.radio_button_unchecked : Icons.do_not_disturb_on_outlined, color: AppColors.muted)
            : Icon(
                s.ok ? Icons.check_circle_rounded : Icons.error_rounded,
                color: (s.ok ? AppColors.ok : AppColors.error).withValues(alpha: pending ? 0.45 : 1),
              );
    final String line;
    if (!enabled) {
      line = 'Desactivada';
    } else if (running) {
      line = 'Leyendo…';
    } else if (s == null) {
      line = 'Sin leer todavía';
    } else {
      final when = 'leída ${fmtUpdated(s.at, now)}';
      line = !s.ok
          ? 'Ha fallado · $when'
          : s.count == 0
              ? 'Sin sesiones por ahora · $when'
              : '${plural(s.count, 'pase', 'pases')} · $when';
    }
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: AdaptiveSwitchTile(
        secondary: leading,
        value: enabled,
        onChanged: (v) {
          if (!v && locked) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Deja al menos una fuente activada')));
            return;
          }
          onChanged(v);
        },
        title: Text(name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            if (enabled && !running && s != null && !s.ok && s.error != null && s.error!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  s.error!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.error),
                ),
              ),
            InkWell(
              onTap: () => openUrl(context, url),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text.rich(
                  TextSpan(children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.open_in_new, size: 15, color: AppColors.amber),
                      ),
                    ),
                    TextSpan(text: 'Abrir la web'),
                  ]),
                  style: TextStyle(fontSize: 13, color: AppColors.amber, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
