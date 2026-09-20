import '../../models/game_phase.dart';
import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

/// Gestionnaire de rôle pour La Petite Fille.
/// La Petite Fille s'éveille secrètement durant la chasse des loups (nightWerewolves).
/// Elle peut espionner leurs délibérations audio et télémétriques, ou fermer les yeux par prudence.
class LittleGirlHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.littleGirl;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) &&
        (state.currentPhase == GamePhase.nightWerewolves ||
            state.currentPhase.isNight);
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final closeEyes = actionPayload['closeEyes'] as bool? ?? false;
    final acknowledged = Set<String>.from(state.nightAcknowledgedPlayerIds)..add(actorId);

    // Enregistre l'action de la petite fille (veille active ou yeux fermés)
    return state.copyWith(
      nightAcknowledgedPlayerIds: acknowledged,
    );
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    final victimId = state.nightPrimaryVictimId;
    final victimName = victimId != null && victimId.isNotEmpty
        ? state.getPlayerName(victimId)
        : null;

    final instruction = victimName != null
        ? 'Les loups ciblent actuellement $victimName ! Écoutez attentivement.'
        : 'Les loups sont en train de délibérer dans l\'obscurité...';

    return RoleUIControls(
      title: 'La Petite Fille',
      instruction: instruction,
      inputType: RoleActionInputType.confirmation,
      confirmButtonLabel: 'Continuer d\'espionner',
      skipButtonLabel: 'Fermer les yeux (Sécurité)',
      canSkip: true,
    );
  }
}
