import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nfc/screen/dahboard.dart';
import 'package:nfc/screen/enhanced_nfc_scanner.dart';
import 'package:app_links/app_links.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      _handleDeepLink(initialUri);
    } catch (_) {}

    _linkSub = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (_) {},
    );
  }

  void _handleDeepLink(Uri? uri) {
    if (uri == null) return;
    if (uri.scheme != 'nfcapp' || uri.host != 'profile') return;

    final encodedData = uri.queryParameters['data'];
    if (encodedData == null || encodedData.isEmpty) return;

    try {
      final decodedJson = utf8.decode(base64Url.decode(encodedData));
      final decodedMap = jsonDecode(decodedJson);
      if (decodedMap is! Map) return;
      final userData = Map<String, dynamic>.from(decodedMap);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = _navigatorKey.currentState;
        if (nav == null) return;
        nav.push(
          MaterialPageRoute(
            builder: (_) => EnhancedNFCDataDisplayScreen(userData: userData),
          ),
        );
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      home: TopContainerExample(),
    );
  }
}

