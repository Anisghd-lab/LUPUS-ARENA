import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'services/unity_ads_service.dart';
import 'ui/screens/lobby_screen.dart';
import 'ui/theme/lupus_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Empêche toute exception non gérée de fermer l'application
  FlutterError.onError = (details) {
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error');
    return true; // Annule le crash et maintient l'app ouverte
  };
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('[Firebase] Initialisation avec options : $e');
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e2) {
      debugPrint('[Firebase] Initialisation par défaut : $e2');
    }
  }

  runApp(const ProviderScope(child: LupusArenaApp()));
}

class LupusArenaApp extends StatelessWidget {
  const LupusArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lupus Arena',
      debugShowCheckedModeBanner: false,
      theme: LupusTheme.darkTheme,
      home: const LobbyScreen(),
    );
  }
}
