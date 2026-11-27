import 'dart:async';

import 'package:flutter/material.dart';

import '../data/updater.dart';
import 'theme.dart';
import 'widgets/open_url.dart';

/// Al abrir la app (Android): si hay versión nueva en GitHub, la ofrece. Sin red, o si
/// GitHub no responde, no dice nada.
Future<void> checkForUpdateOnLaunch(BuildContext context) async {
  if (!Updater.supported) return;
  _watchInstallErrors(context);
  try {
    final u = await Updater.check();
    if (u != null && context.mounted) await offerUpdate(context, u);
  } catch (_) {}
}

/// «Buscar actualizaciones» a mano: siempre pregunta a GitHub y dice el resultado.
Future<void> checkForUpdateNow(BuildContext context) async {
  _watchInstallErrors(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final u = await Updater.check(force: true);
    if (!context.mounted) return;
    if (u == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Tienes la última versión')));
    } else {
      await offerUpdate(context, u);
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('No se ha podido mirar si hay versión nueva: $e')));
  }
}

StreamSubscription<({bool ok, String? message})>? _installSub;

void _watchInstallErrors(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  _installSub ??= Updater.installStatus.listen((s) {
    if (s.ok) return;
    final m = s.message ?? '';
    final text = m.contains('INCOMPATIBLE') || m.contains('signatures')
        ? 'La app instalada está firmada con otra clave. Desinstálala e instala la nueva desde GitHub (solo esta vez).'
        : m.contains('ABORTED') || m.toLowerCase().contains('abort')
            ? 'Instalación cancelada'
            : 'No se ha podido instalar: $m';
    messenger.showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 8)));
  });
}

Future<void> offerUpdate(BuildContext context, AppUpdate u) async {
  final current = await Updater.installedVersion();
  if (!context.mounted) return;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.system_update_rounded, color: AppColors.amber),
      title: Text('Cartelera ${u.version}'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.4),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tienes la $current. ${u.size > 0 ? 'La descarga ocupa ${(u.size / 1048576).toStringAsFixed(0)} MB.' : ''}',
                style: const TextStyle(color: AppColors.muted),
              ),
              if (u.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_plain(u.notes), style: const TextStyle(height: 1.4)),
              ],
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => openUrl(ctx, u.pageUrl),
                child: const Text('Ver en GitHub'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Ahora no')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Actualizar')),
      ],
    ),
  );
  if (go != true || !context.mounted) return;

  if (!await Updater.canInstall()) {
    if (!context.mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Falta un permiso'),
        content: const Text(
          'Android tiene que dejar a Cartelera instalar apps. Activa «Permitir de esta fuente» '
          'en la pantalla que se abre, vuelve y toca otra vez «Actualizar».',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Abrir ajustes')),
        ],
      ),
    );
    if (open == true) await Updater.openInstallSettings();
    return;
  }

  if (!context.mounted) return;
  final progress = ValueNotifier<double?>(null);
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text('Descargando ${u.version}…'),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (_, p, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: p, minHeight: 6, borderRadius: BorderRadius.circular(3)),
              const SizedBox(height: 10),
              Text(p == null ? '' : '${(p * 100).round()} %', style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    ),
  ));
  try {
    final apk = await Updater.download(u, onProgress: (p) => progress.value = p);
    nav.pop();
    await Updater.install(apk); // Android enseña ahora su confirmación
  } catch (e) {
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text('No se ha podido descargar la actualización: $e')));
  } finally {
    progress.dispose();
  }
}

/// Las notas de GitHub vienen en Markdown: se quitan las marcas más comunes.
String _plain(String md) => md
    .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
    .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ')
    .replaceAll(RegExp(r'\*\*|__|`'), '')
    .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!)
    .trim();
