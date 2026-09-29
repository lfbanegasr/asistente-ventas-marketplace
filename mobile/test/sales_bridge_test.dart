import 'package:flutter_test/flutter_test.dart';
import 'package:mesa_ventas_mobile/sales_bridge.dart';

void main() {
  test('solo la app y Cloudflare Access se abren dentro de la sesión', () {
    expect(isTrustedNavigation(salesUrl.toString()), isTrue);
    expect(
      isTrustedNavigation(
        'https://sparkling-king-4c25.cloudflareaccess.com/cdn-cgi/access/login',
      ),
      isTrue,
    );
    expect(
      isTrustedNavigation(
        'https://asistente-ventas-marketplace.lfbanegasr126.workers.dev.evil.test/',
      ),
      isFalse,
    );
    expect(
      isTrustedNavigation(
        'http://asistente-ventas-marketplace.lfbanegasr126.workers.dev/',
      ),
      isFalse,
    );
    expect(
      isTrustedNavigation(
        'https://asistente-ventas-marketplace.lfbanegasr126.workers.dev@evil.test/',
      ),
      isFalse,
    );
  });

  test('el puente de CSV solo acepta archivos esperados', () {
    final export = parseCsvExport(
      '{"fileName":"ventas-2026-09-28.csv","csv":"alias,precio\\nA,170"}',
    );
    expect(export.fileName, 'ventas-2026-09-28.csv');
    expect(export.csv, contains('A,170'));
    expect(
      () => parseCsvExport('{"fileName":"../private.txt","csv":"x"}'),
      throwsFormatException,
    );
    expect(
      () => parseCsvExport('{"fileName":"ventas-2026-09-28.csv","csv":""}'),
      throwsFormatException,
    );
  });
}
