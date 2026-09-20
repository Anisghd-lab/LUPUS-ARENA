import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lupus_arena/models/game_phase.dart';
import 'package:lupus_arena/models/mort_instantanee_event.dart';
import 'package:lupus_arena/services/death_registry_service.dart';
import 'package:lupus_arena/ui/bento/bento_action_panel.dart';
import 'package:lupus_arena/ui/overlays/revealed_death_card_overlay.dart';

void main() {
  setUp(() {
    DeathRegistryService.instance.clearForNewGame();
  });

  group('UI - Succession du Maire', () {
    testWidgets('Affiche la bannière spectateur immersive pour le village', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: BentoActionPanel(
              isCaptain: false,
              isAlive: true,
              phase: GamePhase.captainSuccession,
              timerSeconds: 10,
              survivors: const [],
              onSuccessorSelected: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data?.contains('Le Maire agonisant') == true ||
             w.data?.contains('The dying Mayor') == true)),
        findsOneWidget,
      );
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('Affiche le testament interactif pour le maire mourant', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: BentoActionPanel(
              isCaptain: true,
              isAlive: false,
              phase: GamePhase.captainSuccession,
              timerSeconds: 8,
              survivors: const [
                {'id': 'j2', 'name': 'Bob'},
                {'id': 'j3', 'name': 'Claire'},
              ],
              onSuccessorSelected: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data?.contains('Testament du Maire') == true ||
             w.data?.contains('Mayor\'s Testament') == true)),
        findsOneWidget,
      );
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Claire'), findsOneWidget);
    });
  });

  group('UI - Overlay Carte 3D des Morts', () {
    testWidgets('Respecte le confinement géométrique sans déborder', (WidgetTester tester) async {
      final event = MortInstantaneeEvent(
        joueurId: 'j2',
        nomJoueur: 'Bob',
        roleOriginal: 'LOUP_GAROU',
        causeMort: 'Sentence du Bûcher',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RevealedDeathCardOverlay(
                event: event,
                onCompleted: () {},
              ),
            ),
          ),
        ),
      );

      final containerFinder = find.byKey(const Key('death_card_container'));
      expect(containerFinder, findsOneWidget);

      final Size size = tester.getSize(containerFinder);
      // Conteneur strict : largeur <= 92 px et hauteur <= 138 px
      expect(size.width, lessThanOrEqualTo(95.0));
      expect(size.height, lessThanOrEqualTo(140.0));
    });
  });
}
