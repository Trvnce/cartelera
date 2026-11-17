import 'package:flutter/material.dart';

import '../app_model.dart';
import '../format.dart';
import '../theme.dart';

/// Franja bajo la barra superior: progreso mientras se actualiza y, si no,
/// avisos (error de la última actualización, datos sin confirmar).
class StatusStrip extends StatelessWidget {
  const StatusStrip({super.key, required this.model, required this.onOpenSources});

  final AppModel model;
  final VoidCallback onOpenSources;

  @override
  Widget build(BuildContext context) {
    final repo = model.repo;
    final p = repo.progress;
    Widget child;
    if (p != null) {
      final running = p.running.isEmpty ? 'Leyendo las webs de los cines…' : 'Leyendo ${p.running.join(', ')}…';
      child = Column(
        key: const ValueKey('progress'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: p.done == 0 ? null : p.fraction, minHeight: 3),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    running,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ),
                if (p.total > 1)
                  Text('${p.done} de ${p.total}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      );
    } else if (repo.lastError != null) {
      child = _Notice(
        key: const ValueKey('error'),
        icon: Icons.error_outline,
        color: AppColors.error,
        text: repo.lastError!,
        onTap: onOpenSources,
      );
    } else if (model.staleCount > 0) {
      child = _Notice(
        key: const ValueKey('stale'),
        icon: Icons.history,
        color: AppColors.amber,
        text: '${plural(model.staleCount, 'pase viene', 'pases vienen')} de una lectura anterior: '
            'alguna web ha fallado hoy.',
        onTap: onOpenSources,
      );
    } else {
      child = const SizedBox(key: ValueKey('none'), width: double.infinity);
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.icon, required this.color, required this.text, required this.onTap});
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Text('Fuentes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
