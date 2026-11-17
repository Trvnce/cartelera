import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre una dirección en el navegador externo; avisa si no se puede.
Future<void> openUrl(BuildContext context, String? url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final uri = url == null ? null : Uri.tryParse(url.trim());
  var ok = false;
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok) {
    messenger?.showSnackBar(const SnackBar(content: Text('No se ha podido abrir el enlace')));
  }
}
