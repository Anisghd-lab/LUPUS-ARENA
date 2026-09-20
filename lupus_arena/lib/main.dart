import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'services/locale_provider.dart';
import 'services/lupus_permission_service.dart';
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
  // Éradication absolue du Grey Screen en cas d'erreur de rendu
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('[ErrorWidget] Erreur de rendu interceptée : ${details.exception}');
    return const Material(
      color: Colors.transparent,
      child: SizedBox.shrink(),
    );
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

  // Démarrage du rafraîchisseur et moniteur d'autorisations en arrière-plan
  LupusPermissionService().startBackgroundPermissionMonitor();

  // Initialisation de la langue persistée
  final localeProvider = LocaleProvider.instance;
  await localeProvider.loadSavedLocale();

  runApp(
    ProviderScope(
      child: LupusArenaApp(localeProvider: localeProvider),
    ),
  );
}

class LupusArenaApp extends StatelessWidget {
  final LocaleProvider localeProvider;

  const LupusArenaApp({super.key, required this.localeProvider});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: localeProvider,
      builder: (context, _) {
        final isAr = localeProvider.locale.languageCode == 'ar';
        return MaterialApp(
          title: 'Lupus Arena',
          debugShowCheckedModeBanner: false,
          theme: LupusTheme.darkTheme,
          locale: localeProvider.locale,
          supportedLocales: const [
            Locale('fr'),
            Locale('ar'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: LobbyScreen(localeProvider: localeProvider),
        );
      },
    );
  }
}
