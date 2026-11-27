import 'package:flutter/material.dart';

import '../../data/alerts.dart';
import '../../data/engine.dart' show allSources;
import '../adaptive.dart';
import '../app_model.dart';
import '../format.dart';
import '../motion.dart';
import '../theme.dart';

/// Avisos de pases nuevos (Android): qué películas y qué cines se vigilan, cada cuánto se
/// mira y qué encontró la última comprobación.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.model, this.onOpenFilm});
  final AppModel model;
  final ValueChanged<String>? onOpenFilm;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  ({DateTime? at, String? result})? _last;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    final l = await widget.model.lastAlertRun();
    if (mounted) setState(() => _last = l);
  }

  Future<void> _toggleSource(String id) async {
    final ok = await widget.model.toggleSourceAlert(id);
    if (!ok && mounted) showPermissionDenied(context);
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final a = model.alerts;
        final films = a.films.entries.toList()..sort((x, y) => x.value.toLowerCase().compareTo(y.value.toLowerCase()));
        final sources = [for (final s in allSources) if (model.isSourceEnabled(s.id)) s];
        final now = model.now;
        return Scaffold(
          appBar: adaptiveBar(
            context,
            title: 'Avisos',
            leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Atrás', onPressed: () => Navigator.of(context).maybePop()),
          ),
          body: ListView(
            padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined, color: AppColors.amber),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                a.isEmpty ? 'No vigilas nada todavía' : _summary(a),
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'El móvil vuelve a mirar las webs cada cierto tiempo, aunque la app esté cerrada, '
                          'y te avisa de cada pase que no estaba antes. Android no deja mirar más de una vez '
                          'cada 15 minutos y, con la batería baja o el móvil en reposo, puede tardar más.',
                          style: TextStyle(fontSize: 13.5, height: 1.35, color: AppColors.muted),
                        ),
                        const SizedBox(height: 14),
                        const Text('Mirar cada', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final d in AlertPrefs.intervals)
                              ChoiceChip(
                                label: Text(_intervalLabel(d)),
                                selected: a.interval == d,
                                showCheckmark: false,
                                materialTapTargetSize: MaterialTapTargetSize.padded,
                                onSelected: (_) => model.setAlertInterval(d),
                              ),
                          ],
                        ),
                        if (!a.isEmpty) ...[
                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: Motion.medium,
                            child: Text(
                              key: ValueKey(_last?.at),
                              _last?.at == null
                                  ? 'Aún no se ha hecho ninguna comprobación en segundo plano.'
                                  : 'Última comprobación ${fmtUpdated(_last!.at!, now)}: ${_last!.result ?? '—'}',
                              style: const TextStyle(fontSize: 13, color: AppColors.muted),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const _Section('Películas'),
              if (films.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Toca la campana en la ficha de una película para que te avise de cada pase nuevo, '
                    'en cualquier cine. Sigue vigilando aunque ahora no esté en cartel.',
                    style: TextStyle(fontSize: 13.5, height: 1.35, color: AppColors.muted),
                  ),
                ),
              for (final f in films)
                ListTile(
                  leading: const Icon(Icons.movie_outlined),
                  title: Text(f.value, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _filmLine(model, f.key),
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  onTap: model.sessionsOfFilm(f.key).isEmpty || widget.onOpenFilm == null ? null : () => widget.onOpenFilm!(f.key),
                  trailing: IconButton(
                    tooltip: 'Dejar de vigilar',
                    icon: const Icon(Icons.notifications_off_outlined),
                    onPressed: () => model.toggleFilmAlert(f.key, f.value),
                  ),
                ),
              const SizedBox(height: 8),
              const _Section('Cines'),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Cualquier pase nuevo en ese cine, sea de la película que sea.',
                  style: TextStyle(fontSize: 13.5, height: 1.35, color: AppColors.muted),
                ),
              ),
              for (final s in sources)
                AdaptiveSwitchTile(
                  secondary: Icon(
                    model.isSourceWatched(s.id) ? Icons.notifications_active : Icons.notifications_none,
                    color: model.isSourceWatched(s.id) ? AppColors.amber : AppColors.muted,
                  ),
                  title: Text(s.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                  value: model.isSourceWatched(s.id),
                  onChanged: (_) => _toggleSource(s.id),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _summary(AlertPrefs a) {
    final parts = [
      if (a.films.isNotEmpty) plural(a.films.length, 'película', 'películas'),
      if (a.sources.isNotEmpty) plural(a.sources.length, 'cine', 'cines'),
    ];
    return 'Vigilando ${parts.join(' y ')}';
  }

  static String _intervalLabel(Duration d) => d.inMinutes < 60 ? '${d.inMinutes} min' : '${d.inHours} h';

  static String _filmLine(AppModel model, String key) {
    final n = model.sessionsOfFilm(key).length;
    return n == 0 ? 'Sin pases ahora mismo' : 'En cartel · ${plural(n, 'pase', 'pases')}';
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 12.5, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: AppColors.amber)),
      );
}

/// Aviso de que, sin permiso de notificaciones, los avisos se guardan pero no suenan.
void showPermissionDenied(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(
      content: Text('Sin permiso de notificaciones no podrás recibir los avisos. Actívalo en los ajustes de Android.'),
      duration: Duration(seconds: 5),
    ));
}
