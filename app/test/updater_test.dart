import 'package:cartelera/data/updater.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _rel(String tag, {List<String> assets = const ['Cartelera.apk'], bool pre = false, bool draft = false}) => {
      'tag_name': tag,
      'prerelease': pre,
      'draft': draft,
      'body': '## Novedades\n- **Avisos** de pases nuevos',
      'html_url': 'https://github.com/Trvnce/cartelera/releases/tag/$tag',
      'assets': [
        for (final a in assets) {'name': a, 'browser_download_url': 'https://example.com/$a', 'size': 1000},
      ],
    };

void main() {
  test('compara versiones número a número', () {
    expect(Updater.compareVersions('1.10.0', '1.9.2'), 1);
    expect(Updater.compareVersions('1.1', '1.1.0'), 0);
    expect(Updater.compareVersions('1.1.0+10100', '1.1.0'), 0);
    expect(Updater.compareVersions('0.9.9', '1.0.0'), -1);
  });

  test('elige la versión vX.Y.Z más nueva con APK e ignora las de iOS', () {
    final u = Updater.latestRelease([
      _rel('ios-12', assets: ['Cartelera.ipa']),
      _rel('v1.3.0', pre: true),
      _rel('v1.4.0', draft: true),
      _rel('v1.2.0'),
      _rel('v1.10.0', assets: ['notas.txt']), // sin APK
      _rel('v1.1.0'),
    ]);
    expect(u?.version, '1.2.0');
    expect(u?.apkUrl, 'https://example.com/Cartelera.apk');
    expect(u?.size, 1000);
  });

  test('sin Releases de Android no hay actualización', () {
    expect(Updater.latestRelease([_rel('ios-3', assets: ['Cartelera.ipa'])]), isNull);
    expect(Updater.latestRelease([]), isNull);
  });
}
