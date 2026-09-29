import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class UrlHelper {
  /// Abre chat de WhatsApp con mensaje pre-redactado o comparte vía SharePlus como fallback
  static Future<void> openWhatsAppChat({
    String? phone,
    required String text,
  }) async {
    final cleanPhone = phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final encoded = Uri.encodeComponent(text);

    Uri uri;
    if (cleanPhone.isNotEmpty) {
      final phoneWithCountry = cleanPhone.startsWith('591') ? cleanPhone : '591$cleanPhone';
      uri = Uri.parse('https://wa.me/$phoneWithCountry?text=$encoded');
    } else {
      uri = Uri.parse('whatsapp://send?text=$encoded');
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      final webUri = Uri.parse('https://api.whatsapp.com/send?text=$encoded');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback garantizado: compartir mediante hoja de sistema
    await SharePlus.instance.share(ShareParams(
      text: text,
      title: 'Enviar por WhatsApp',
    ));
  }

  /// Abre Google Maps con la ubicación especificada
  static Future<void> openMapForLocation(String place) async {
    final query = place.toLowerCase().contains('santa cruz')
        ? place
        : '$place, Santa Cruz, Bolivia';

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}
