import 'dart:convert';

final salesUrl = Uri.parse(
  'https://asistente-ventas-marketplace.lfbanegasr126.workers.dev/login',
);

bool isSalesOrigin(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == salesUrl.host &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443);
}

bool isTrustedNavigation(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    return false;
  }
  return uri.host == salesUrl.host ||
      uri.host.endsWith('.cloudflareaccess.com');
}

class CsvExport {
  const CsvExport(this.fileName, this.csv);
  final String fileName;
  final String csv;
}

CsvExport parseCsvExport(String message) {
  if (message.length > 2000000) {
    throw const FormatException('CSV demasiado grande');
  }
  final data = jsonDecode(message);
  if (data is! Map<String, dynamic>) {
    throw const FormatException('CSV inválido');
  }
  final fileName = data['fileName'];
  final csv = data['csv'];
  if (fileName is! String ||
      !RegExp(r'^ventas-\d{4}-\d{2}-\d{2}\.csv$').hasMatch(fileName) ||
      csv is! String ||
      csv.isEmpty ||
      csv.length > 1900000) {
    throw const FormatException('CSV inválido');
  }
  return CsvExport(fileName, csv);
}
