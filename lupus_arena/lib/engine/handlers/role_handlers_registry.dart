import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'abominable_sectarian_handler.dart';
import 'actor_handler.dart';
import 'bear_tamer_handler.dart';
import 'big_bad_wolf_handler.dart';
import 'crow_handler.dart';
import 'devoted_servant_handler.dart';
import 'elder_handler.dart';
import 'fox_handler.dart';
import 'infect_father_of_wolves_handler.dart';
import 'role_action_handler.dart';
import 'rusty_sword_knight_handler.dart';
import 'scapegoat_handler.dart';
import 'soul_stealer_handler.dart';
import 'stuttering_judge_handler.dart';
import 'thief_handler.dart';
import 'three_brothers_handler.dart';
import 'two_sisters_handler.dart';
import 'wild_child_handler.dart';
import 'wolf_cub_handler.dart';

class RoleHandlersRegistry {
  static final Map<GameRole, RoleActionHandler> _handlers = {
    GameRole.twoSisters: TwoSistersHandler(),
    GameRole.threeBrothers: ThreeBrothersHandler(),
    GameRole.fox: FoxHandler(),
    GameRole.bearTamer: BearTamerHandler(),
    GameRole.stutteringJudge: StutteringJudgeHandler(),
    GameRole.knightRustySword: RustySwordKnightHandler(),
    GameRole.servantMaid: DevotedServantHandler(),
    GameRole.actor: ActorHandler(),
    GameRole.scapegoat: ScapegoatHandler(),
    GameRole.elder: ElderHandler(),
    GameRole.bigBadWolf: BigBadWolfHandler(),
    GameRole.vileFatherOfWolves: InfectFatherOfWolvesHandler(),
    GameRole.wolfCub: WolfCubHandler(),
    GameRole.wildChild: WildChildHandler(),
    GameRole.raven: CrowHandler(),
    GameRole.sectLeader: AbominableSectarianHandler(),
    GameRole.thiefOfHearts: SoulStealerHandler(),
    GameRole.thief: ThiefHandler(),
  };

  static RoleActionHandler? getHandlerFor(GameRole role) => _handlers[role];

  /// Dispatch générique sécurisé pour appliquer l'action d'un rôle
  static GameState dispatchAction(
    GameState state, {
    required GameRole role,
    required String actorId,
    required Map<String, dynamic> payload,
  }) {
    final handler = _handlers[role];
    if (handler != null && handler.canAct(state, actorId)) {
      return handler.executeAction(state, actorId: actorId, actionPayload: payload);
    }
    return state;
  }

  /// Récupération des contrôles UI du rôle actif
  static RoleUIControls getControls(GameState state, String playerId) {
    final role = state.playerRoles[playerId];
    if (role == null) return RoleUIControls.empty;
    final handler = _handlers[role];
    if (handler != null && handler.canAct(state, playerId)) {
      return handler.getUIControls(state, playerId);
    }
    return RoleUIControls.empty;
  }
}
