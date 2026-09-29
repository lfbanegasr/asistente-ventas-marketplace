import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'sales_bridge.dart';

void main() => runApp(const SalesApp());

class SalesApp extends StatelessWidget {
  const SalesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi mesa de ventas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF172A3A),
          primary: const Color(0xFF172A3A),
          secondary: const Color(0xFFDF7447),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F4EF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF172A3A),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: const SalesHome(),
    );
  }
}

class SalesHome extends StatefulWidget {
  const SalesHome({super.key});

  @override
  State<SalesHome> createState() => _SalesHomeState();
}

class _SalesHomeState extends State<SalesHome> {
  late final WebViewController _webView;
  int _progress = 0;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF3F4EF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _progress = 0;
                _loadError = null;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _progress = 100);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(
                () => _loadError =
                    'No se pudo abrir la app. Revisa tu conexión e inténtalo de nuevo.',
              );
            }
          },
          onNavigationRequest: (request) {
            if (!request.isMainFrame || isTrustedNavigation(request.url)) {
              return NavigationDecision.navigate;
            }
            final uri = Uri.tryParse(request.url);
            if (uri != null &&
                (uri.scheme == 'https' || uri.scheme == 'mailto')) {
              unawaited(_openExternal(uri));
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..addJavaScriptChannel('SalesExport', onMessageReceived: _shareCsv)
      ..loadRequest(salesUrl);
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showMessage('No se pudo abrir el enlace externo.');
      }
    } catch (_) {
      _showMessage('No se pudo abrir el enlace externo.');
    }
  }

  Future<void> _shareCsv(JavaScriptMessage message) async {
    try {
      final current = await _webView.currentUrl();
      if (current == null || !isSalesOrigin(current)) return;
      final export = parseCsvExport(message.message);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(utf8.encode(export.csv), mimeType: 'text/csv'),
          ],
          fileNameOverrides: [export.fileName],
          title: 'Copia privada de ventas',
          sharePositionOrigin: Rect.fromLTWH(
            0,
            0,
            MediaQuery.sizeOf(context).width,
            80,
          ),
        ),
      );
    } catch (_) {
      _showMessage('No se pudo preparar el CSV. Intenta exportarlo de nuevo.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _retry() {
    setState(() {
      _loadError = null;
      _progress = 0;
    });
    unawaited(_webView.loadRequest(salesUrl));
  }

  Future<void> _back() async {
    if (await _webView.canGoBack()) {
      await _webView.goBack();
    } else if (Platform.isAndroid) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Mi mesa de ventas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: () => unawaited(_webView.reload()),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              WebViewWidget(controller: _webView),
              if (_progress < 100 && _loadError == null)
                Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress / 100,
                  ),
                ),
              if (_loadError != null)
                ColoredBox(
                  color: const Color(0xFFF3F4EF),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 48),
                          const SizedBox(height: 16),
                          Text(_loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _retry,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
