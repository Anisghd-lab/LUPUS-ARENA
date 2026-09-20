import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_phase.dart';
import '../../models/game_room.dart';
import '../../models/player_model.dart';
import '../../services/app_translations.dart';
import '../../services/death_registry_service.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';
import 'bento_player_tile.dart';

/// Panneau d'actions Bento contextuel compact pour chaque rôle.
/// Format compact sans overflow, sans narrations superflues,
/// avec boutons d'actions directs et brefs.
class BentoActionPanel extends StatefulWidget {
  final GameRoom room;
  final String currentUserId;
  final String? selectedTargetId;
  final GameRole? inspectedRole;
  final bool isHost;
  final VoidCallback onNextPhase;
  final ValueChanged<String?> onVote;
  final ValueChanged<String> onInspect;
  final VoidCallback onCompleteSeerTurn;
  final void Function([String? targetId]) onWitchSave;
  final ValueChanged<String> onWitchPoison;
  final VoidCallback onWitchPass;
  final ValueChanged<String>? onDefenderProtect;
  final ValueChanged<String>? onBlackWolfSilence;
  final void Function(String p1, String p2)? onCupidBind;
  final ValueChanged<String>? onThiefSteal;
  final ValueChanged<GameRole>? onThiefChooseRole;
  final ValueChanged<List<String>>? onPiperCharm;
  final ValueChanged<String>? onInfect;
  final ValueChanged<String>? onHunterShoot;
  final ValueChanged<String>? onCaptainPass;
  final ValueChanged<String>? onCrowDesignate;
  final ValueChanged<String>? onPyromaniacDouse;
  final VoidCallback? onPyromaniacIgnite;
  final VoidCallback? onPyromaniacPass;
  final ValueChanged<String>? onFoxSniff;
  final VoidCallback? onFoxPass;
  final ValueChanged<String>? onWhiteWolfDevour;
  final VoidCallback? onWhiteWolfPass;
  final ValueChanged<bool>? onLittleGirlToggleEyes;
  final ValueChanged<String>? onWerewolvesCatchLittleGirl;
  final bool isAdmin;
  final VoidCallback? onPassDebate;
  final ValueListenable<int>? countdownListenable;
  final ValueChanged<String>? onSelectTarget;

  // Paramètres injectables pour les tests et la modularité
  final bool? isCaptain;
  final bool? isAlive;
  final GamePhase? phase;
  final int? timerSeconds;
  final List<dynamic>? survivors;
  final ValueChanged<String>? onSuccessorSelected;

  BentoActionPanel({
    super.key,
    GameRoom? room,
    String? currentUserId,
    this.selectedTargetId,
    this.inspectedRole,
    this.isHost = false,
    this.isAdmin = false,
    VoidCallback? onNextPhase,
    ValueChanged<String?>? onVote,
    ValueChanged<String>? onInspect,
    VoidCallback? onCompleteSeerTurn,
    void Function([String? targetId])? onWitchSave,
    ValueChanged<String>? onWitchPoison,
    VoidCallback? onWitchPass,
    this.onDefenderProtect,
    this.onBlackWolfSilence,
    this.onCupidBind,
    this.onThiefSteal,
    this.onThiefChooseRole,
    this.onPiperCharm,
    this.onInfect,
    this.onHunterShoot,
    this.onCaptainPass,
    this.onCrowDesignate,
    this.onPyromaniacDouse,
    this.onPyromaniacIgnite,
    this.onPyromaniacPass,
    this.onFoxSniff,
    this.onFoxPass,
    this.onWhiteWolfDevour,
    this.onWhiteWolfPass,
    this.onLittleGirlToggleEyes,
    this.onWerewolvesCatchLittleGirl,
    this.onPassDebate,
    this.countdownListenable,
    this.onSelectTarget,
    this.isCaptain,
    this.isAlive,
    this.phase,
    this.timerSeconds,
    this.survivors,
    this.onSuccessorSelected,
  })  : room = _synthesizeRoom(room, currentUserId, isCaptain, isAlive, phase, timerSeconds, survivors),
        currentUserId = currentUserId ?? 'test_user',
        onNextPhase = onNextPhase ?? _noop,
        onVote = onVote ?? _noopValue,
        onInspect = onInspect ?? _noopValue,
        onCompleteSeerTurn = onCompleteSeerTurn ?? _noop,
        onWitchSave = onWitchSave ?? (([_]) => {}),
        onWitchPoison = onWitchPoison ?? _noopValue,
        onWitchPass = onWitchPass ?? _noop;

  static void _noop() {}
  static void _noopValue(dynamic _) {}

  static GameRoom _synthesizeRoom(
    GameRoom? room,
    String? currentUserId,
    bool? isCaptain,
    bool? isAlive,
    GamePhase? phase,
    int? timerSeconds,
    List<dynamic>? survivors,
  ) {
    if (room != null && isCaptain == null && isAlive == null && phase == null && timerSeconds == null && survivors == null) {
      return room;
    }
    final uid = currentUserId ?? 'test_user';
    final bool isUserDead = DeathRegistryService.instance.isDead(uid);
    final alive = isUserDead ? false : (isAlive ?? room?.players[uid]?.isAlive ?? (room != null ? false : true));
    final captain = isCaptain ?? room?.players[uid]?.isCaptain ?? false;
    final ph = phase ?? room?.phase ?? GamePhase.lobby;
    final timer = timerSeconds ?? room?.timerSeconds ?? 10;

    final Map<String, PlayerModel> players = Map<String, PlayerModel>.from(room?.players ?? {});
    if (!players.containsKey(uid)) {
      players[uid] = PlayerModel(
        id: uid,
        name: 'Moi',
        isAlive: alive,
        isCaptain: captain,
      );
    } else {
      players[uid] = players[uid]!.copyWith(
        isAlive: alive,
        isCaptain: captain,
      );
    }

    if (survivors != null) {
      for (final s in survivors) {
        if (s is Map) {
          final sid = (s['id'] ?? '').toString();
          final sname = (s['name'] ?? sid).toString();
          players[sid] = PlayerModel(
            id: sid,
            name: sname,
            isAlive: !DeathRegistryService.instance.isDead(sid),
          );
        } else if (s is PlayerModel) {
          players[s.id] = DeathRegistryService.instance.isDead(s.id)
              ? s.copyWith(isAlive: false)
              : s;
        }
      }
    }

    return room?.copyWith(
      phase: ph,
      timerSeconds: timer,
      players: players,
      captainId: captain ? uid : room.captainId,
      pendingCaptainId: (captain && !alive) ? uid : room.pendingCaptainId,
    ) ?? GameRoom(
      roomCode: 'TEST',
      hostId: uid,
      phase: ph,
      timerSeconds: timer,
      captainId: captain ? uid : null,
      pendingCaptainId: (captain && !alive) ? uid : null,
      players: players,
    );
  }

  @override
  State<BentoActionPanel> createState() => _BentoActionPanelState();
}

class _BentoActionPanelState extends State<BentoActionPanel> {
  // Sélection des deux amoureux par Cupidon
  String? _cupidLover1Id;
  String? _cupidLover2Id;

  // Sélection des deux cibles par le Joueur de Flûte
  String? _piperTarget1Id;
  String? _piperTarget2Id;

  // Sélection des deux cibles par les Loups (1er: Dévorer, 2ème: Museler)
  String? _wolfVictimId;
  String? _wolfMuteId;

  // Sélection du successeur par le Capitaine défunt (Testament)
  String? _selectedCaptainSuccessorId;

  // État d'espionnage de la Petite Fille
  bool _littleGirlEyesClosed = false;

  GameRoom get effectiveRoom => widget.room;

  void _handleCupidSelection(String id) {
    final target = widget.room.players[id];
    if (target == null || !target.isAlive) return;

    if (_cupidLover1Id == null) {
      setState(() => _cupidLover1Id = id);
    } else if (_cupidLover1Id == id) {
      setState(() => _cupidLover1Id = null);
    } else {
      setState(() => _cupidLover2Id = id);
      widget.onCupidBind?.call(_cupidLover1Id!, id);
    }
  }

  void _handlePiperSelection(String id) {
    final target = widget.room.players[id];
    if (target == null || !target.isAlive || target.isCharmed) return;

    final uncharmedLiving = widget.room.alivePlayers.where((p) => !p.isCharmed).toList();
    if (uncharmedLiving.length <= 1) {
      HapticFeedback.lightImpact();
      setState(() => _piperTarget1Id = id);
      widget.onPiperCharm?.call([id]);
      return;
    }

    if (_piperTarget1Id == null) {
      HapticFeedback.selectionClick();
      setState(() => _piperTarget1Id = id);
    } else if (_piperTarget1Id == id) {
      HapticFeedback.selectionClick();
      setState(() => _piperTarget1Id = null);
    } else {
      HapticFeedback.lightImpact();
      setState(() => _piperTarget2Id = id);
      widget.onPiperCharm?.call([_piperTarget1Id!, id]);
    }
  }

  void _handleWerewolfSelection(String id) {
    final target = widget.room.players[id];
    if (target == null || !target.isAlive || DeathRegistryService.instance.isDead(id)) return;

    final rawVictimId = _wolfVictimId ?? widget.room.nightVictimId;
    final victimPlayer = rawVictimId != null ? widget.room.players[rawVictimId] : null;
    final victimId = (victimPlayer != null && victimPlayer.isAlive && !DeathRegistryService.instance.isDead(rawVictimId!))
        ? rawVictimId
        : null;

    final rawMuteId = _wolfMuteId ?? widget.room.blackWolfTargetId;
    final mutePlayer = (rawMuteId != null && rawMuteId.isNotEmpty)
        ? widget.room.players[rawMuteId]
        : null;
    final muteId = (mutePlayer != null && mutePlayer.isAlive && !DeathRegistryService.instance.isDead(rawMuteId!))
        ? rawMuteId
        : null;

    if (victimId == null) {
      // 1ère sélection : Dévorer (la proie des loups)
      setState(() => _wolfVictimId = id);
      widget.onVote(id);
    } else if (victimId == id) {
      // Second clic sur la même victime : Dé-sélection / annulation pour choisir une autre victime
      setState(() => _wolfVictimId = null);
      widget.onVote(null);
    } else if (muteId == null) {
      // 2ème sélection : Museler (Loup Noir / silence)
      setState(() => _wolfMuteId = id);
      widget.onBlackWolfSilence?.call(id);
      // Auto-validation directe dès que les 2 cibles sont sélectionnées !
      widget.onNextPhase();
    } else if (muteId == id) {
      // Dé-sélection de la 2ème cible
      setState(() => _wolfMuteId = null);
    } else {
      // Remplacement de la 2ème cible et auto-validation directe
      setState(() => _wolfMuteId = id);
      widget.onBlackWolfSilence?.call(id);
      widget.onNextPhase();
    }
  }

  @override
  void didUpdateWidget(covariant BentoActionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nettoyage impératif des sous-états lors des transitions de phase ou de round
    final oldPhase = oldWidget.phase ?? oldWidget.room.phase;
    final newPhase = widget.phase ?? widget.room.phase;
    final oldRound = oldWidget.room.round;
    final newRound = widget.room.round;
    if (oldPhase != newPhase || oldRound != newRound) {
      _cupidLover1Id = null;
      _cupidLover2Id = null;
      _piperTarget1Id = null;
      _piperTarget2Id = null;
      _wolfVictimId = null;
      _wolfMuteId = null;
      _selectedCaptainSuccessorId = null;
    } else if (widget.selectedTargetId != oldWidget.selectedTargetId) {
      final myRole = widget.room.players[widget.currentUserId]?.role;
      final isEvil = myRole?.isEvil == true || myRole?.isWolfTeam == true || myRole == GameRole.whiteWerewolf || widget.isAdmin;

      if (widget.selectedTargetId != null) {
        if (newPhase == GamePhase.nightCupid && (myRole == GameRole.cupid || widget.isAdmin)) {
          _handleCupidSelection(widget.selectedTargetId!);
        } else if (newPhase == GamePhase.nightPiper && (myRole == GameRole.piedPiper || widget.isAdmin)) {
          _handlePiperSelection(widget.selectedTargetId!);
        } else if (newPhase == GamePhase.nightWerewolves && isEvil) {
          _handleWerewolfSelection(widget.selectedTargetId!);
        }
      } else if (oldWidget.selectedTargetId != null) {
        // Désélection déclenchée par un second clic sur la même carte (selectedTargetId repasse à null)
        final unselectedId = oldWidget.selectedTargetId!;
        if (newPhase == GamePhase.nightWerewolves && isEvil) {
          if (_wolfVictimId == unselectedId || widget.room.nightVictimId == unselectedId) {
            setState(() => _wolfVictimId = null);
            widget.onVote(null);
          } else if (_wolfMuteId == unselectedId || widget.room.blackWolfTargetId == unselectedId) {
            setState(() => _wolfMuteId = null);
          }
        } else if (newPhase == GamePhase.nightCupid && (myRole == GameRole.cupid || widget.isAdmin)) {
          if (_cupidLover1Id == unselectedId) {
            setState(() => _cupidLover1Id = null);
          }
        } else if (newPhase == GamePhase.nightPiper && (myRole == GameRole.piedPiper || widget.isAdmin)) {
          if (_piperTarget1Id == unselectedId) {
            setState(() => _piperTarget1Id = null);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final room = effectiveRoom;
      final currentUserId = widget.currentUserId;
      final isMeDead = DeathRegistryService.instance.isDead(currentUserId);
      final me = room.players[currentUserId] ??
          PlayerModel(
            id: currentUserId,
            name: context.tr('me'),
            isAlive: isMeDead ? false : (widget.isAlive ?? true),
            isCaptain: widget.isCaptain ?? false,
          );

      final isAlive = isMeDead ? false : (widget.isAlive ?? me.isAlive);
      final role = me.role;
      final phase = widget.phase ?? room.phase;
      final isDevMode = widget.room.isDevRoom || widget.isAdmin;
      final isDyingCaptain = (widget.isCaptain == true && widget.isAlive == false) ||
          (room.pendingCaptainId == currentUserId) ||
          (me.isCaptain && !isAlive) ||
          (room.captainId == currentUserId && !isAlive);
      final selectedTarget = widget.selectedTargetId != null
          ? room.players[widget.selectedTargetId]
          : null;

      return BentoCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        borderColor: LupusColors.borderGlow,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête compact avec badge de décompte et badge de la cible sélectionnée
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('strategic_actions'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: LupusColors.sunAmber,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (phase.isNight ? LupusColors.arcaneViolet : LupusColors.sunAmber).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (phase.isNight ? LupusColors.arcaneViolet : LupusColors.sunAmber).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        context.tr(phase.isNight ? 'phase_tag_night' : 'phase_tag_day'),
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: phase.isNight ? const Color(0xFFD4B2FF) : LupusColors.sunAmber,
                        ),
                      ),
                    ),
                  ],
                ),
                if (selectedTarget != null)
                  Flexible(
                    child: Container(
                      margin: const EdgeInsetsDirectional.only(end: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: LupusColors.arcaneGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: LupusColors.arcaneGold.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: LupusColors.arcaneGold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              selectedTarget.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: LupusColors.arcaneGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Zone d'action standardisée et stabilisée (hauteur minimale calibrée sur la Sorcière)
            Container(
              constraints: const BoxConstraints(minHeight: 120),
              alignment: Alignment.center,
              width: double.infinity,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                  return currentChild ?? const SizedBox.shrink();
                },
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: SizedBox(
                  key: ValueKey('action_panel_${phase.name}_${role.name}_${isAlive}_${isDyingCaptain}_${selectedTarget?.id ?? "none"}'),
                  width: double.infinity,
                  child: _buildRoleActionDispatcher(
                    context: context,
                    phase: phase,
                    role: role,
                    me: me,
                    selectedTarget: selectedTarget,
                    isAlive: isAlive,
                    isDevMode: isDevMode,
                    isDyingCaptain: isDyingCaptain,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e, stack) {
      debugPrint('[BentoActionPanel] Erreur fatale dans build(): $e\n$stack');
      return BentoCard(
        key: const ValueKey('action_panel_safe_fallback'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        borderColor: LupusColors.borderGlow,
        child: Container(
          constraints: const BoxConstraints(minHeight: 120),
          alignment: Alignment.center,
          child: _buildVotesClosedBanner(
            message: context.tr('phase_in_progress'),
          ),
        ),
      );
    }
  }

  /// Dispatcher d'action stratégique selon la phase et le rôle actif
  Widget _buildRoleActionDispatcher({
    required BuildContext context,
    required GamePhase phase,
    required GameRole role,
    required PlayerModel me,
    required PlayerModel? selectedTarget,
    required bool isAlive,
    required bool isDevMode,
    required bool isDyingCaptain,
  }) {
    try {
      // 1. CHASSEUR AU DERNIER SOUFFLE
      if (phase == GamePhase.hunterDeathChoice) {
        if (widget.room.pendingHunterId == widget.currentUserId || isDevMode) {
          return _buildHunterSection(selectedTarget);
        } else {
          return _buildHunterSpectatorSection();
        }
      }

      // 2. CAPITAINE / MAIRE DÉFUNT (TESTAMENT) OU SPECTATEUR
      if (phase == GamePhase.captainSuccession || phase == GamePhase.mayorSuccession) {
        if (isDyingCaptain || isDevMode) {
          return _buildCaptainSuccessionSection(selectedTarget);
        } else {
          return _buildCaptainSuccessionSpectatorSection();
        }
      }

      // 3. JOUEUR ÉLIMINÉ SANS ACTION PARTICULIÈRE (HORS DEV-MODE)
      if (!isAlive && !isDevMode) {
        return _buildEliminatedSection();
      }

      // 4. VOLEUR (NUIT 1)
      if (phase == GamePhase.nightThief) {
        if (role == GameRole.thief || role == GameRole.thiefOfHearts || isDevMode) {
          return _buildThiefSection(selectedTarget);
        } else {
          return _buildNightSleepingSection();
        }
      }

      // 5. CUPIDON (NUIT 1)
      if (phase == GamePhase.nightCupid) {
        if (role == GameRole.cupid || isDevMode) {
          return _buildCupidSection(selectedTarget);
        } else {
          return _buildNightSleepingSection();
        }
      }

      // 6. VOYANTE
      if (phase == GamePhase.nightSeer) {
        if (role == GameRole.seer || isDevMode) {
          return _buildSeerSection(selectedTarget);
        } else {
          return _buildNightSleepingSection();
        }
      }

      // 7. SALVATEUR
      if (phase == GamePhase.nightDefender) {
        if (role == GameRole.defender || isDevMode) {
          return _buildDefenderSection(selectedTarget);
        } else {
          return _buildNightSleepingSection();
        }
      }

      // 8. LOUPS-GAROUS & LOUP NOIR
      if (phase == GamePhase.nightWerewolves || phase == GamePhase.nightBlackWolf) {
        if (role.isEvil || isDevMode) {
          return _buildWerewolvesSection(me, selectedTarget);
        } else if (role == GameRole.littleGirl) {
          return _buildLittleGirlSection(selectedTarget);
        } else {
          return _buildNightSleepingSection();
        }
      }

      // 8.B LOUP-GAROU BLANC (NUIT DU LOUP BLANC)
      if (phase == GamePhase.nightWhiteWerewolf) {
        if (role == GameRole.whiteWerewolf || isDevMode) {
          return _buildWhiteWerewolfSection(selectedTarget);
        } else {
          return _buildNightSleepingSection();
        }
      }

      // 8.C RENARD (NUIT DU RENARD)
      if (phase == GamePhase.nightFox) {
        if (role == GameRole.fox || isDevMode) {
          return _buildFoxSection(selectedTarget);
        } else {
          return _buildNightSleepingSection();
        }
      }

      // 9. SORCIÈRE
      if (phase == GamePhase.nightWitch) {
        if (role == GameRole.witch || me.roleInitial == GameRole.witch || isDevMode) {
          final witchPlayer = widget.room.playerList.firstWhere(
            (p) => p.role == GameRole.witch || p.roleInitial == GameRole.witch,
            orElse: () => me,
          );
          return _buildWitchSection(witchPlayer, selectedTarget);
        } else {
          return _buildNightSleepingSection();
        }
      }

      // 9.B PYROMANE
      if (phase == GamePhase.nightPyromaniac) {
        if (role == GameRole.pyromaniac || isDevMode) {
          return _buildPyromaniacSection(selectedTarget);
        } else {
          return _buildNightSleepingSection();
        }
      }

      // 9.C JOUEUR DE FLÛTE
      if (phase == GamePhase.nightPiper) {
        if (role == GameRole.piedPiper || isDevMode) {
          return _buildPiperSection(selectedTarget);
        } else {
          return _buildNightSleepingSection();
        }
      }

      // 10. ÉLECTION DU CAPITAINE / MAIRE
      if (phase == GamePhase.captainElection || phase == GamePhase.mayorElection) {
        return _buildCaptainElectionSection(selectedTarget);
      }

      // 10.B DISCOURS D'OUVERTURE DU MAIRE
      if (phase == GamePhase.mayorSpeechOpening) {
        return _buildMayorSpeechOpeningSection();
      }

      // 11. DÉBAT TOUR PAR TOUR
      if (phase == GamePhase.dayDebate) {
        return _buildDebateSection();
      }

      // 11.B DISCOURS DE CLÔTURE DU MAIRE
      if (phase == GamePhase.mayorSpeechClosing) {
        return _buildMayorSpeechClosingSection();
      }

      // 12. SCRUTIN DU BÛCHER & SECOND VOTE
      if (phase == GamePhase.dayVoting || phase == GamePhase.dayTieBreakVote) {
        return _buildVotingSection(me, selectedTarget);
      }

      // 13. EXÉCUTION DU VERDICT (« Le Verdict Tombe ») / PLAIDOIRIE
      if (phase == GamePhase.dayResolution || phase == GamePhase.dayDefense) {
        return _buildVotesClosedBanner();
      }

      // 14. AUBE / ANNONCE DES MORTS (joueurs attendent la résolution)
      if (phase == GamePhase.morningAnnouncement) {
        return _buildNightSleepingSection();
      }

      // PAR DÉFAUT : NUIT OU JOUR
      if (phase.isNight) {
        if (role == GameRole.raven) {
          return _buildRavenSection(selectedTarget);
        }
        return _buildNightSleepingSection();
      }

      return _buildVotesClosedBanner();
    } catch (e, stack) {
      debugPrint('BentoActionPanel error in _buildRoleActionDispatcher: $e\n$stack');
      return _buildVotesClosedBanner(
        message: context.tr('phase_in_progress'),
      );
    }
  }

  // ==========================================
  // --- MODULES DE RÔLES COMPACTS SANS OVERFLOW ---
  // ==========================================

  /// Module Sorcière : Utilisation combinée possible des deux potions (Vie & Mort) dans la même nuit
  /// Vérification continue des stocks et rétrogradation en Simple Villageois si les 2 stocks sont épuisés
  Widget _buildWitchSection(PlayerModel witch, PlayerModel? selectedTarget) {
    final wolfVictimId = widget.room.nightVictimId;
    final wolfVictim = wolfVictimId != null ? widget.room.players[wolfVictimId] : null;
    final isHealed = widget.room.witchHealed;
    final hasHeal = (witch.potionsVie > 0 && !isHealed) || widget.isAdmin;

    final poisonVictimId = widget.room.witchPoisonVictimId;
    final poisonVictim = poisonVictimId != null ? widget.room.players[poisonVictimId] : null;
    final hasPoison = (witch.potionsMort > 0 && poisonVictimId == null) || widget.isAdmin;

    final hasActed = isHealed || poisonVictim != null;
    final isDechue = witch.potionsVie == 0 && witch.potionsMort == 0 && !widget.isAdmin;

    // ÉTAT 1 : Déchue en simple villageoise (0 potions restantes)
    if (isDechue) {
      return Column(
        key: const ValueKey('action_witch_exhausted'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x1FF43F5E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: LupusColors.bloodRed.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Text('🥀', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('witch_exhausted_msg'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFECDD3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: LupusColors.textMuted,
                side: const BorderSide(color: LupusColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: widget.onWitchPass,
              icon: const Icon(Icons.bedtime_outlined, size: 15),
              label: Text(context.tr('pass_my_turn'), style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
      );
    }

    // ÉTAT 2 : Toutes les actions ont été validées (sauvé et/ou empoisonné, plus de potion utilisable)
    if (hasActed && (!hasHeal || wolfVictim == null) && (!hasPoison || poisonVictim != null)) {
      return Column(
        key: ValueKey('action_witch_confirmed_${isHealed}_${poisonVictimId ?? "none"}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x2210B981),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: LupusColors.poisonGreen.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isHealed)
                  Text(
                    context.tr('witch_victim_saved', {'name': wolfVictim?.name ?? context.tr('the_victim')}),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: LupusColors.poisonGreen),
                  ),
                if (poisonVictim != null)
                  Text(
                    context.tr('witch_victim_poisoned', {'name': poisonVictim.name}),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFFECDD3)),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: widget.onWitchPass,
              icon: const Icon(Icons.check_circle_outline, size: 15),
              label: Text(context.tr('complete_turn'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
            ),
          ),
        ],
      );
    }

    // ÉTAT 3 : En action active avec choix disponibles
    return Column(
      key: ValueKey('action_witch_active_${selectedTarget?.id ?? "none"}_${isHealed}_$hasPoison'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bandeau stocks
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x1F10B981),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: LupusColors.poisonGreen.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('potion_life_count', {'count': '${witch.potionsVie}'}),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: witch.potionsVie > 0 ? LupusColors.poisonGreen : LupusColors.textMuted,
                ),
              ),
              Text(
                context.tr('potion_death_count', {'count': '${witch.potionsMort}'}),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: witch.potionsMort > 0 ? LupusColors.arcaneCrimson : LupusColors.textMuted,
                ),
              ),
            ],
          ),
        ),

        // Section Guérison
        if (isHealed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: const Color(0x2210B981),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: LupusColors.poisonGreen.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: LupusColors.poisonGreen, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr('victim_saved_pill', {'name': wolfVictim?.name ?? context.tr('the_victim')}),
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: LupusColors.poisonGreen),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        else if (wolfVictim != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: const Color(0x221E1B4B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasHeal ? LupusColors.poisonGreen.withValues(alpha: 0.6) : LupusColors.border.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: LupusColors.bloodRed.withValues(alpha: 0.25),
                  child: Icon(
                    BentoPlayerTile.avatarIcons[wolfVictim.avatarIndex % BentoPlayerTile.avatarIcons.length],
                    size: 13,
                    color: const Color(0xFFFECDD3),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr('witch_victim_label', {'name': wolfVictim.name}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
                if (hasHeal)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => widget.onWitchSave(wolfVictim.id),
                    icon: const Icon(Icons.healing_rounded, size: 13),
                    label: Text(
                      context.tr('witch_save_btn'),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10.5),
                    ),
                  ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: const Color(0x1F1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Text('🕊️', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr('no_wolf_victim_tonight'),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFBAE6FD)),
                  ),
                ),
              ],
            ),
          ),

        // Section Poison & Passer
        Row(
          children: [
            if (poisonVictim != null)
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0x22450A0A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: LupusColors.bloodRed.withValues(alpha: 0.6)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    context.tr('poison_pill', {'name': poisonVictim.name}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFFECDD3)),
                  ),
                ),
              )
            else ...[
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: (hasPoison &&
                          selectedTarget != null &&
                          selectedTarget.isAlive &&
                          selectedTarget.id != widget.currentUserId)
                      ? ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LupusColors.bloodRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => widget.onWitchPoison(selectedTarget.id),
                          icon: const Icon(Icons.science_rounded, size: 13),
                          label: Text(
                            context.tr('witch_poison_target', {'name': selectedTarget.name}),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10.5),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: const Color(0x1F450A0A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasPoison ? LupusColors.bloodRed.withValues(alpha: 0.3) : Colors.white10,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            hasPoison ? context.tr('tap_to_poison') : context.tr('vial_empty'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: hasPoison ? const Color(0xFFFECDD3) : LupusColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            SizedBox(
              height: 36,
              child: hasActed
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: widget.onWitchPass,
                      icon: const Icon(Icons.check_circle_outline, size: 13),
                      label: Text(context.tr('finish'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                    )
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LupusColors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: widget.onWitchPass,
                      child: Text(context.tr('witch_pass'), style: const TextStyle(fontSize: 10.5)),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  /// Module Loups-Garous : Sélection multi-cibles séquentielle (1er: Dévorer, 2e: Museler) + Auto-Validation
  Widget _buildWerewolvesSection(PlayerModel me, PlayerModel? selectedTarget) {
    final rawVictimId = _wolfVictimId ?? widget.room.nightVictimId ?? me.targetVoteId;
    final victimPlayer = rawVictimId != null ? widget.room.players[rawVictimId] : null;
    final effectiveVictimId = (victimPlayer != null && victimPlayer.isAlive && !DeathRegistryService.instance.isDead(rawVictimId!))
        ? rawVictimId
        : null;
    final victim = effectiveVictimId != null ? widget.room.players[effectiveVictimId] : null;

    final rawMuteId = _wolfMuteId ?? widget.room.blackWolfTargetId;
    final mutePlayer = (rawMuteId != null && rawMuteId.isNotEmpty)
        ? widget.room.players[rawMuteId]
        : null;
    final effectiveMuteId = (mutePlayer != null && mutePlayer.isAlive && !DeathRegistryService.instance.isDead(rawMuteId!))
        ? rawMuteId
        : null;
    final muted = effectiveMuteId != null ? widget.room.players[effectiveMuteId] : null;

    final isDoubleActionComplete = effectiveVictimId != null &&
        effectiveMuteId != null &&
        effectiveVictimId != effectiveMuteId;

    final hasInfectWolf = widget.room.alivePlayers.any(
      (p) => p.role == GameRole.vileFatherOfWolves,
    );
    final canInfect = (hasInfectWolf || widget.isAdmin) && !widget.room.vileFatherInfectionUsed;
    final isInfected = effectiveVictimId != null && widget.room.infectedPlayerId == effectiveVictimId;

    final String statusText;
    if (victim == null) {
      statusText = context.tr('wolf_step1_select_devour');
    } else if (muted == null) {
      statusText = context.tr('wolf_step2_select_mute', {'name': victim.name});
    } else {
      statusText = context.tr('wolf_assault_ready', {'victim': victim.name, 'muted': muted.name});
    }

    return Column(
      key: ValueKey('action_wolves_${effectiveVictimId ?? "none"}_${effectiveMuteId ?? "none"}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Bandeau de statut réactif
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: isDoubleActionComplete
                ? const Color(0x2206D6A0)
                : const Color(0x22DC2626),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDoubleActionComplete
                  ? const Color(0xFF06D6A0).withValues(alpha: 0.6)
                  : const Color(0xFFDC2626).withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              const Text('🐺', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isDoubleActionComplete
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFFECDD3),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Deux emplacements côte à côte (1er: Dévorer, 2e: Museler)
        Row(
          children: [
            // Emplacement 1 : DÉVORER (Rouge Sang)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (effectiveVictimId != null) {
                    // Si une proie est déjà sélectionnée, un clic sur le slot l'annule pour choisir une autre victime
                    if (selectedTarget != null && selectedTarget.id != effectiveVictimId && selectedTarget.isAlive && !DeathRegistryService.instance.isDead(selectedTarget.id)) {
                      setState(() => _wolfVictimId = selectedTarget.id);
                      widget.onVote(selectedTarget.id);
                    } else {
                      setState(() => _wolfVictimId = null);
                      widget.onVote(null);
                    }
                  } else if (selectedTarget != null && selectedTarget.isAlive && !DeathRegistryService.instance.isDead(selectedTarget.id)) {
                    setState(() => _wolfVictimId = selectedTarget.id);
                    widget.onVote(selectedTarget.id);
                  }
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: victim != null
                        ? const Color(0xFFDC2626).withValues(alpha: 0.25)
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: victim != null
                          ? const Color(0xFFDC2626)
                          : LupusColors.border.withValues(alpha: 0.5),
                      width: victim != null ? 1.4 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant_rounded, size: 14, color: Color(0xFFF87171)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          victim != null ? '🥩 ${victim.name}' : context.tr('wolf_devour_btn'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: victim != null ? FontWeight.w900 : FontWeight.w600,
                            color: victim != null ? Colors.white : LupusColors.textMuted,
                          ),
                        ),
                      ),
                      if (victim != null)
                        const Icon(Icons.close_rounded, size: 12, color: Color(0xFFF87171)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Emplacement 2 : MUSELER (Violet Silence)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (effectiveMuteId != null) {
                    if (selectedTarget != null && selectedTarget.id != effectiveMuteId && selectedTarget.isAlive && !DeathRegistryService.instance.isDead(selectedTarget.id)) {
                      setState(() => _wolfMuteId = selectedTarget.id);
                      widget.onBlackWolfSilence?.call(selectedTarget.id);
                      if (effectiveVictimId != null) {
                        widget.onNextPhase();
                      }
                    } else {
                      setState(() => _wolfMuteId = null);
                    }
                  } else if (selectedTarget != null && selectedTarget.isAlive && !DeathRegistryService.instance.isDead(selectedTarget.id)) {
                    setState(() => _wolfMuteId = selectedTarget.id);
                    widget.onBlackWolfSilence?.call(selectedTarget.id);
                    if (effectiveVictimId != null) {
                      widget.onNextPhase();
                    }
                  }
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: muted != null
                        ? const Color(0xFF9333EA).withValues(alpha: 0.25)
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: muted != null
                          ? const Color(0xFFC084FC)
                          : LupusColors.border.withValues(alpha: 0.5),
                      width: muted != null ? 1.4 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_off_rounded, size: 14, color: Color(0xFFC084FC)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          muted != null ? '🔇 ${muted.name}' : context.tr('wolf_mute_btn'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: muted != null ? FontWeight.w900 : FontWeight.w600,
                            color: muted != null ? Colors.white : LupusColors.textMuted,
                          ),
                        ),
                      ),
                      if (muted != null)
                        const Icon(Icons.close_rounded, size: 12, color: Color(0xFFC084FC)),
                    ],
                  ),
                ),
              ),
            ),

            // Optionnel : Bouton Infection de l'Infect Père des Loups
            if (canInfect && victim != null) ...[
              const SizedBox(width: 6),
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isInfected
                        ? LupusColors.poisonGreen
                        : const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => widget.onInfect?.call(victim.id),
                  child: Text(
                    isInfected ? context.tr('wolf_infected_pill') : context.tr('wolf_infect_btn'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10.5),
                  ),
                ),
              ),
            ],
          ],
        ),

        // 3. Optionnel : Bouton Dénicher l'espionne (Petite Fille) si un villageois est sélectionné
        if (selectedTarget != null &&
            selectedTarget.isAlive &&
            !selectedTarget.isWolf &&
            widget.onWerewolvesCatchLittleGirl != null) ...[
          const SizedBox(height: 5),
          SizedBox(
            height: 32,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0x1AFFC6FF),
                foregroundColor: const Color(0xFFFFC6FF),
                side: const BorderSide(color: Color(0xFFFFC6FF), width: 1.0),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => widget.onWerewolvesCatchLittleGirl?.call(selectedTarget.id),
              icon: const Icon(Icons.visibility_rounded, size: 14, color: Color(0xFFFFC6FF)),
              label: Text(
                context.tr('wolf_unmask_peeker_btn', {'name': selectedTarget.name}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10.5),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Module Voyante : 3 états étanches (Épuisé / Révélé / Enquête)
  Widget _buildSeerSection(PlayerModel? selectedTarget) {
    final me = widget.room.players[widget.currentUserId] ??
        widget.room.playerList.first;
    final seerPlayer = widget.room.playerList.firstWhere(
      (p) => p.role == GameRole.seer || p.roleInitial == GameRole.seer,
      orElse: () => me,
    );
    final visionsLeft = seerPlayer.visionsRestantes;

    // ÉTAT 1 : Épuisé / Déchue en simple villageois (0 visions restantes)
    if (visionsLeft == 0 && !widget.isAdmin) {
      return Column(
        key: const ValueKey('action_seer_exhausted'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: const Color(0x1FF43F5E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: LupusColors.arcaneCrimson.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Text('🔮', style: TextStyle(fontSize: 13)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('seer_exhausted_msg'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFECDD3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: LupusColors.textMuted,
                side: const BorderSide(color: LupusColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: widget.onCompleteSeerTurn,
              icon: const Icon(Icons.check_rounded, size: 15),
              label: Text(context.tr('pass_my_turn'), style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
      );
    }

    // ÉTAT 2 : Révélation de l'identité / Rôle inspecté
    if (widget.inspectedRole != null) {
      final role = widget.inspectedRole!;
      return Column(
        key: ValueKey('action_seer_revealed_${role.name}_${selectedTarget?.id ?? "unknown"}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: role.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: role.accentColor, width: 1.2),
            ),
            child: Row(
              children: [
                Icon(role.icon, color: role.accentColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${selectedTarget?.name ?? context.tr("target")} : ${role.displayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: LupusColors.arcanePurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: widget.onCompleteSeerTurn,
              icon: const Icon(Icons.check_rounded, size: 15),
              label: Text(
                context.tr('validate'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ),
        ],
      );
    }

    // ÉTAT 3 : Sélection de la cible à sonder
    final canInspect = (visionsLeft > 0 || widget.isAdmin) &&
        selectedTarget != null &&
        selectedTarget.isAlive &&
        selectedTarget.id != widget.currentUserId;

    final String inspectLabel = selectedTarget != null
        ? context.tr('inspect_target', {'name': selectedTarget.name})
        : context.tr('inspect_select');

    return Column(
      key: ValueKey('action_seer_select_${selectedTarget?.id ?? "waiting"}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Indicateur quota dynamique de visions Voyante
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x1F9333EA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: LupusColors.arcanePurple.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🔮', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('seer_visions_left', {'count': '$visionsLeft'}),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: visionsLeft > 0
                          ? const Color(0xFFE9D5FF)
                          : LupusColors.textMuted,
                    ),
                  ),
                ],
              ),
              Text(
                canInspect ? context.tr('ready_to_inspect') : context.tr('choose_a_target'),
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC084FC),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LupusColors.arcanePurple,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: LupusColors.arcanePurple.withValues(alpha: 0.25),
                    disabledForegroundColor: Colors.white38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: canInspect
                      ? () => widget.onInspect(selectedTarget.id)
                      : null,
                  icon: const Icon(Icons.visibility_rounded, size: 15),
                  label: Text(
                    inspectLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: LupusColors.arcanePurple,
                  side: const BorderSide(color: LupusColors.arcanePurple),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: widget.onCompleteSeerTurn,
                icon: const Icon(Icons.check_rounded, size: 15),
                label: Text(context.tr('validate'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Module Salvateur : 3 états exclusifs (Déjà protégé / Interdit consécutif / Sélection active)
  Widget _buildDefenderSection(PlayerModel? selectedTarget) {
    final currentProtectedId = widget.room.currentProtectedPlayerId;
    final currentProtected = (currentProtectedId != null && currentProtectedId.isNotEmpty)
        ? widget.room.players[currentProtectedId]
        : null;

    // ÉTAT 1 : Déjà sous protection cette nuit
    if (currentProtected != null) {
      return Column(
        key: ValueKey('action_defender_confirmed_${currentProtected.id}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x223A86FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF3A86FF).withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.security_rounded, size: 16, color: Color(0xFF60A5FA)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('defender_protected_title', {'name': currentProtected.name}),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFBFDBFE),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('defender_protected_subtitle'),
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final lastProtectedId = widget.room.lastProtectedPlayerId;
    final lastProtected = (lastProtectedId != null && lastProtectedId.isNotEmpty)
        ? widget.room.players[lastProtectedId]
        : null;

    final isSameAsLast = selectedTarget != null &&
        lastProtectedId != null &&
        selectedTarget.id == lastProtectedId;

    final bool canProtect = selectedTarget != null &&
        selectedTarget.isAlive &&
        !isSameAsLast;

    final String buttonText;
    if (selectedTarget == null) {
      buttonText = context.tr('protect_select');
    } else if (isSameAsLast) {
      buttonText = context.tr('protect_forbidden', {'name': selectedTarget.name});
    } else {
      buttonText = context.tr('protect_target', {'name': selectedTarget.name});
    }

    return Column(
      key: ValueKey('action_defender_select_${selectedTarget?.id ?? "waiting"}_$isSameAsLast'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSameAsLast)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: const Color(0x22DC2626),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFCA5A5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr('defender_consecutive_warning', {'name': selectedTarget.name}),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFFECDD3)),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A86FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF3A86FF).withValues(alpha: 0.25),
                    disabledForegroundColor: Colors.white38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: canProtect
                      ? () => widget.onDefenderProtect?.call(selectedTarget.id)
                      : null,
                  icon: const Icon(Icons.security_rounded, size: 15),
                  label: Text(
                    buttonText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 38,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: LupusColors.textSecondary,
                  side: const BorderSide(color: LupusColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: widget.onNextPhase,
                child: Text(context.tr('pass'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
        if (lastProtected != null && !isSameAsLast)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.tr('last_protected_info', {'name': lastProtected.name}),
              textAlign: TextAlign.center,
              style: const TextStyle(color: LupusColors.textMuted, fontSize: 10),
            ),
          ),
      ],
    );
  }



  /// Module Chasseur au dernier souffle : Tir de vengeance ultime
  Widget _buildHunterSection(PlayerModel? selectedTarget) {
    final bool canShoot = selectedTarget != null &&
        selectedTarget.isAlive &&
        selectedTarget.id != widget.currentUserId;

    return Column(
      key: ValueKey('action_hunter_ready_${selectedTarget?.id ?? "waiting"}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: const Color(0x22F59E0B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: LupusColors.sunAmber.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Text('🏹', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr('hunter_last_breath_banner'),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFDE68A),
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LupusColors.sunAmber,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: LupusColors.sunAmber.withValues(alpha: 0.25),
                    disabledForegroundColor: Colors.black38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: canShoot
                      ? () {
                          HapticFeedback.heavyImpact();
                          widget.onHunterShoot?.call(selectedTarget.id);
                        }
                      : null,
                  icon: const Icon(Icons.crisis_alert_rounded, size: 15),
                  label: Text(
                    selectedTarget != null
                        ? context.tr('shoot_target', {'name': selectedTarget.name})
                        : context.tr('shoot_select'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 38,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0x33450A0A),
                  foregroundColor: LupusColors.textMuted,
                  side: BorderSide(color: LupusColors.border.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: widget.onNextPhase,
                icon: const Icon(Icons.cancel_outlined, size: 14),
                label: Text(
                  context.tr('pass'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Module Spectateur : Le Chasseur prend sa décision ultime
  Widget _buildHunterSpectatorSection() {
    return Container(
      key: const ValueKey('action_hunter_spectator'),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0x22F59E0B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LupusColors.sunAmber.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.crisis_alert_rounded, color: LupusColors.sunAmber, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              context.tr('hunter_spectator_banner'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFDE68A),
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Module Corbeau : Malédiction nocturne (+2 voix d'office le lendemain)
  Widget _buildRavenSection(PlayerModel? selectedTarget) {
    final crowTargetId = widget.room.expandedRolesState.crowTargetId;
    final crowTarget = (crowTargetId != null && crowTargetId.isNotEmpty)
        ? widget.room.players[crowTargetId]
        : null;

    // ÉTAT 1 : Malédiction déjà posée
    if (crowTarget != null) {
      return Column(
        key: ValueKey('action_raven_confirmed_${crowTarget.id}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x221E1B4B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Text('🦅', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('raven_cursed_title', {'name': crowTarget.name}),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE0E7FF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('raven_cursed_subtitle'),
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // ÉTAT 2 : Sélection de la cible à maudire
    final bool canDesignate = selectedTarget != null &&
        selectedTarget.isAlive &&
        selectedTarget.id != widget.currentUserId;

    return Column(
      key: ValueKey('action_raven_select_${selectedTarget?.id ?? "waiting"}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: const Color(0x22312E81),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Text('🦅', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr('raven_action_banner'),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFC7D2FE),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4338CA),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF4338CA).withValues(alpha: 0.25),
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: canDesignate
                ? () => widget.onCrowDesignate?.call(selectedTarget.id)
                : null,
            icon: const Icon(Icons.visibility_off_rounded, size: 15),
            label: Text(
              selectedTarget != null
                  ? context.tr('raven_curse_target', {'name': selectedTarget.name})
                  : context.tr('raven_select_target'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
            ),
          ),
        ),
      ],
    );
  }

  /// Module Nuit : Sommeil du village pendant le tour des autres rôles
  Widget _buildNightSleepingSection() {
    return Container(
      key: const ValueKey('action_night_sleeping'),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0x221E1B4B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bedtime_rounded, color: Color(0xFFA5B4FC), size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              context.tr('night_in_progress_msg'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE0E7FF),
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Module Spectateur : Joueur éliminé observant la partie
  Widget _buildEliminatedSection() {
    return Container(
      key: const ValueKey('action_spectator_dead'),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0x2218181B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.visibility_outlined, color: Colors.white60, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              context.tr('eliminated_spectator_msg'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bandeau d'état solennel lorsque les votes sont clos (Verdict du tribunal)
  Widget _buildVotesClosedBanner({String? message}) {
    return Container(
      key: ValueKey('action_votes_closed_${message ?? "default"}'),
      height: 40,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0x22450A0A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: LupusColors.arcaneCrimson.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚖️', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message ?? context.tr('silence_votes_closed_msg'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFCA5A5),
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Module Scrutin du Bûcher : Flux conditionnel strict et mutuellement exclusif
  Widget _buildVotingSection(PlayerModel me, PlayerModel? selectedTarget) {
    final phase = widget.room.phase;
    final isTieBreak = phase == GamePhase.dayTieBreakVote;
    final isEligible = !isTieBreak || widget.room.tiedPlayerIds.contains(selectedTarget?.id);
    final currentVoteTargetId = me.targetVoteId;
    final totalAlive = widget.room.alivePlayers.length;
    final totalVoted = widget.room.alivePlayers.where((p) => p.targetVoteId != null).length;
    final allVoted = totalAlive > 0 && totalVoted >= totalAlive;

    // Tous les survivants ont voté : affichage du bandeau de dépouillement immédiat
    if (allVoted) {
      return Container(
        key: const ValueKey('action_voting_all_voted'),
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: LupusColors.bloodRed.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: LupusColors.bloodRed.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(LupusColors.bloodRed),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.tr('voting_all_recorded', {'voted': '$totalVoted', 'total': '$totalAlive'}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ÉTAT 2 : L'utilisateur a déjà voté et peut annuler
    if (currentVoteTargetId != null) {
      final votedTarget = widget.room.players[currentVoteTargetId];
      final votedName = votedTarget?.name ?? context.tr('suspect');

      return SizedBox(
        key: ValueKey('action_voting_voted_$currentVoteTargetId'),
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0x2E10B981),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                    width: 0.9,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: Color(0xFF34D399),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${context.tr("vote_cast_against", {"name": votedName})}${me.isCaptain ? " (x2)" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD1FAE5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFCA5A5),
                  side: BorderSide(
                    color: LupusColors.arcaneCrimson.withValues(alpha: 0.6),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => widget.onVote(null),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: Text(
                  context.tr('cancel'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ÉTAT 3 : L'utilisateur n'a pas encore voté
    final String voteText;
    if (selectedTarget != null) {
      voteText = '${context.tr("vote_against_target", {"name": selectedTarget.name})}${me.isCaptain ? " (x2)" : ""}';
    } else {
      voteText = isTieBreak ? context.tr('vote_tie_break') : context.tr('vote_select');
    }

    final bool canVote = !DeathRegistryService.instance.isDead(widget.currentUserId) &&
        selectedTarget != null &&
        selectedTarget.isAlive &&
        !DeathRegistryService.instance.isDead(selectedTarget.id) &&
        selectedTarget.id != widget.currentUserId &&
        isEligible;

    return SizedBox(
      key: ValueKey('action_voting_select_${selectedTarget?.id ?? "waiting"}'),
      height: 40,
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: LupusColors.bloodRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: LupusColors.bloodRed.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: canVote ? () => widget.onVote(selectedTarget.id) : null,
        icon: const Icon(Icons.how_to_vote_rounded, size: 15),
        label: Text(
          voteText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    );
  }

  /// Module Capitaine (Testament du Capitaine) : Vue dédiée pour le Capitaine mourant
  Widget _buildCaptainSuccessionSection(PlayerModel? selectedTarget) {
    final countdownListenable = widget.countdownListenable ??
        ValueNotifier<int>(widget.timerSeconds ?? (effectiveRoom.timerSeconds > 0 ? effectiveRoom.timerSeconds : 10));

    return ValueListenableBuilder<int>(
      valueListenable: countdownListenable,
      builder: (context, countdown, _) {
        if (countdown <= 0) {
          return Container(
            key: const ValueKey('action_captain_succession_expired'),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0x33450A0A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: LupusColors.arcaneCrimson.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(LupusColors.arcaneCrimson),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('captain_expired_transmission'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFA4A4),
                  ),
                ),
              ],
            ),
          );
        }

        final survivors = widget.survivors != null
            ? widget.survivors!.map((s) {
                if (s is Map) {
                  return PlayerModel(
                    id: (s['id'] ?? '').toString(),
                    name: (s['name'] ?? '').toString(),
                    isAlive: true,
                  );
                }
                return s as PlayerModel;
              }).toList()
            : effectiveRoom.alivePlayers
                .where((p) => p.id != widget.currentUserId)
                .toList();

        final effectiveSuccessorId =
            _selectedCaptainSuccessorId ?? selectedTarget?.id;
        final effectiveSuccessor = effectiveSuccessorId != null
            ? (survivors.cast<PlayerModel?>().firstWhere(
                (p) => p?.id == effectiveSuccessorId,
                orElse: () => effectiveRoom.players[effectiveSuccessorId],
              ))
            : null;
        final isValidSuccessor = effectiveSuccessor != null &&
            effectiveSuccessor.isAlive &&
            effectiveSuccessor.id != widget.currentUserId;

        return Column(
          key: ValueKey('action_captain_succession_${effectiveSuccessorId ?? "none"}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête : « Testament du Capitaine » + Compte à rebours circulaire de 10s
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x332A1D05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: LupusColors.arcaneGold.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: LupusColors.arcaneGold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history_edu_rounded,
                      size: 16,
                      color: LupusColors.arcaneGold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr('mayor_testament'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: LupusColors.arcaneGold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          context.tr('mayor_testament_subtitle'),
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: LupusColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Compte à rebours circulaire de 10 secondes
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: (countdown / 10.0).clamp(0.0, 1.0),
                          strokeWidth: 2.5,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation(
                            countdown <= 3
                                ? LupusColors.arcaneCrimson
                                : LupusColors.arcaneGold,
                          ),
                        ),
                        Text(
                          '$countdown',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: countdown <= 3
                                ? const Color(0xFFFFA4A4)
                                : LupusColors.arcaneGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Liste interactive des survivants
            if (survivors.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  context.tr('no_survivors_available'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: LupusColors.textMuted),
                ),
              )
            else
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: survivors.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final survivor = survivors[i];
                    final isChosen = survivor.id == effectiveSuccessorId;
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedCaptainSuccessorId = survivor.id);
                        widget.onSelectTarget?.call(survivor.id);
                        widget.onSuccessorSelected?.call(survivor.id);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isChosen
                              ? LupusColors.arcaneGold.withValues(alpha: 0.22)
                              : const Color(0x440F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isChosen
                                ? LupusColors.arcaneGold
                                : LupusColors.border.withValues(alpha: 0.4),
                            width: isChosen ? 1.4 : 0.8,
                          ),
                          boxShadow: isChosen
                              ? [
                                  BoxShadow(
                                    color: LupusColors.arcaneGold.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: isChosen
                                  ? LupusColors.arcaneGold
                                  : const Color(0xFF2E3856),
                              child: Text(
                                survivor.name.isNotEmpty
                                    ? survivor.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isChosen ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              survivor.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isChosen ? FontWeight.w900 : FontWeight.w700,
                                color: isChosen ? Colors.white : LupusColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 6),

            // Bouton doré : « Léguer l'écharpe à [Nom] »
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isValidSuccessor
                            ? LupusColors.arcaneGold
                            : const Color(0x333F2E05),
                        foregroundColor: isValidSuccessor
                            ? Colors.black
                            : LupusColors.textMuted,
                        disabledBackgroundColor: const Color(0x223F2E05),
                        disabledForegroundColor: LupusColors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: isValidSuccessor ? 3 : 0,
                      ),
                      onPressed: isValidSuccessor
                          ? () {
                              widget.onSuccessorSelected?.call(effectiveSuccessor.id);
                              widget.onCaptainPass?.call(effectiveSuccessor.id);
                            }
                          : null,
                      icon: Icon(
                        Icons.military_tech_rounded,
                        size: 16,
                        color: isValidSuccessor ? Colors.black : LupusColors.textMuted,
                      ),
                      label: Text(
                        isValidSuccessor
                            ? context.tr('bequeath_sash_target', {'name': effectiveSuccessor.name})
                            : context.tr('choose_survivor_hint'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: isValidSuccessor ? Colors.black : LupusColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0x33450A0A),
                      foregroundColor: LupusColors.textMuted,
                      side: BorderSide(
                        color: LupusColors.border.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: widget.onNextPhase,
                    icon: const Icon(Icons.casino_outlined, size: 14),
                    label: Text(
                      context.tr('auto_pass_badge'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Module Spectateur / Village : Bandeau immersif non interactif avec compte à rebours synchronisé de 10s
  Widget _buildCaptainSuccessionSpectatorSection() {
    final countdownListenable = widget.countdownListenable ??
        ValueNotifier<int>(widget.timerSeconds ?? (effectiveRoom.timerSeconds > 0 ? effectiveRoom.timerSeconds : 10));

    return ValueListenableBuilder<int>(
      valueListenable: countdownListenable,
      builder: (context, countdown, _) {
        return Container(
          key: const ValueKey('action_captain_succession_spectator'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xE60D111F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: LupusColors.arcaneGold.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: LupusColors.arcaneGold.withValues(alpha: 0.12),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: LupusColors.arcaneGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: LupusColors.arcaneGold.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.military_tech_outlined,
                  size: 18,
                  color: LupusColors.arcaneGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('captain_dying_banner'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('captain_dying_subtitle'),
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: LupusColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Compte à rebours synchronisé de 10s
              SizedBox(
                width: 28,
                height: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: (countdown / 10.0).clamp(0.0, 1.0),
                      strokeWidth: 2.5,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(
                        countdown <= 3
                            ? LupusColors.arcaneCrimson
                            : LupusColors.arcaneGold,
                      ),
                    ),
                    Text(
                      '$countdown',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: countdown <= 3
                            ? const Color(0xFFFFA4A4)
                            : LupusColors.arcaneGold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Module Élection du Capitaine
  Widget _buildCaptainElectionSection(PlayerModel? selectedTarget) {
    return SizedBox(
      key: ValueKey('action_captain_election_${selectedTarget?.id ?? "none"}'),
      height: 40,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: LupusColors.sunAmber,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: (selectedTarget != null && selectedTarget.isAlive)
            ? () => widget.onVote(selectedTarget.id)
            : null,
        icon: const Icon(Icons.military_tech_rounded, size: 15),
        label: Text(
          selectedTarget != null
              ? context.tr('elect_captain_target', {'name': selectedTarget.name})
              : context.tr('elect_captain_select'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    );
  }

  /// Module Discours d'Ouverture du Maire
  Widget _buildMayorSpeechOpeningSection() {
    final mayorId = widget.room.captainId ?? widget.room.expandedRolesState.mayorPlayerId ?? widget.room.currentSpeakerId;
    final isMayor = mayorId == widget.currentUserId || widget.isAdmin;
    final mayorName = widget.room.players[mayorId]?.name ?? context.tr('role_mayor');

    if (isMayor) {
      return SizedBox(
        key: const ValueKey('action_mayor_opening_speech_button'),
        height: 40,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: LupusColors.sunAmber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: widget.onPassDebate,
          icon: const Icon(Icons.record_voice_over_rounded, size: 16, color: Colors.black),
          label: Text(
            context.tr('mayor_open_debate_btn'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('action_mayor_opening_speech_waiting'),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LupusColors.sunAmber.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.record_voice_over_rounded, color: LupusColors.sunAmber, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.tr('mayor_opening_debate_waiting', {'name': mayorName}),
              style: const TextStyle(
                color: LupusColors.sunAmber,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Module Débat tour par tour
  Widget _buildDebateSection() {
    final isSpeaker = widget.room.currentSpeakerId == widget.currentUserId;
    if (isSpeaker || widget.isAdmin) {
      return SizedBox(
        key: const ValueKey('action_debate_speaker'),
        height: 40,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FFCC),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: widget.onPassDebate,
          icon: const Text('🎙️', style: TextStyle(fontSize: 16)),
          label: Text(
            isSpeaker ? context.tr('pass_speaking_turn') : context.tr('force_speaker_turn_mj'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final speaker = widget.room.players[widget.room.currentSpeakerId];
    return Container(
      key: const ValueKey('action_debate_listener'),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LupusColors.border.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.record_voice_over_rounded, color: Color(0xFF00FFCC), size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.tr('listen_speaker', {'name': speaker?.name ?? context.tr('speaker')}),
              style: const TextStyle(
                color: Color(0xFF00FFCC),
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Module Discours de Clôture du Maire
  Widget _buildMayorSpeechClosingSection() {
    final mayorId = widget.room.captainId ?? widget.room.expandedRolesState.mayorPlayerId ?? widget.room.currentSpeakerId;
    final isMayor = mayorId == widget.currentUserId || widget.isAdmin;
    final mayorName = widget.room.players[mayorId]?.name ?? context.tr('role_mayor');

    if (isMayor) {
      return SizedBox(
        key: const ValueKey('action_mayor_closing_button'),
        height: 40,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: LupusColors.arcaneCrimson,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: widget.onPassDebate,
          icon: const Icon(Icons.gavel_rounded, size: 16, color: Colors.white),
          label: Text(
            context.tr('mayor_close_debate_btn'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('action_mayor_closing_waiting'),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LupusColors.arcaneCrimson.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gavel_rounded, color: LupusColors.arcaneCrimson, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.tr('mayor_closing_debate_waiting', {'name': mayorName}),
              style: const TextStyle(
                color: Color(0xFFFFA4A4),
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Module Voleur / Voleur d'Âmes (Nuit 1) : Choix entre cartes non attribuées ou vol d'identité
  Widget _buildThiefSection(PlayerModel? selectedTarget) {
    final available = widget.room.thiefAvailableRoles;
    final myPlayer = widget.room.players[widget.currentUserId];
    final bool isSoulStealer = myPlayer?.role == GameRole.thiefOfHearts ||
        (!widget.room.players.values.any((p) => p.role == GameRole.thief && p.isAlive) &&
            widget.room.players.values.any((p) => p.role == GameRole.thiefOfHearts && p.isAlive));

    // Détermination de l'ID effectif du voleur (pour empêcher de voler sa propre carte)
    String thiefActorId = widget.currentUserId;
    if (myPlayer?.role != GameRole.thief && myPlayer?.role != GameRole.thiefOfHearts) {
      final activeThief = widget.room.players.values.cast<PlayerModel?>().firstWhere(
            (p) => p != null && p.isAlive && (p.role == GameRole.thief || p.role == GameRole.thiefOfHearts),
            orElse: () => null,
          );
      if (activeThief != null) thiefActorId = activeThief.id;
    }

    return Column(
      key: ValueKey('action_thief_${selectedTarget?.id ?? "waiting"}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (available.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: const Color(0x228338EC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF8338EC).withValues(alpha: 0.4)),
            ),
            child: Text(
              context.tr('thief_available_roles'),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFC084FC)),
            ),
          ),
          Row(
            children: available.map((role) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: role.isEvil ? const Color(0xFF7F1D1D) : const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: () => widget.onThiefChooseRole?.call(role),
                      icon: Icon(role.icon, size: 14),
                      label: Text(
                        AppTranslations.translateRoleName(context, role.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSoulStealer ? const Color(0xFFFF0054) : const Color(0xFF8338EC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: (selectedTarget != null &&
                          selectedTarget.isAlive &&
                          selectedTarget.id != thiefActorId)
                      ? () => widget.onThiefSteal?.call(selectedTarget.id)
                      : null,
                  icon: Icon(isSoulStealer ? Icons.heart_broken_rounded : Icons.swap_horiz_rounded, size: 15),
                  label: Text(
                    selectedTarget != null
                        ? (isSoulStealer
                            ? context.tr('thief_steal_soul_target', {'name': selectedTarget.name})
                            : context.tr('steal_target', {'name': selectedTarget.name}))
                        : (isSoulStealer
                            ? context.tr('thief_steal_soul')
                            : context.tr('steal_select')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: LupusColors.textSecondary,
                  side: const BorderSide(color: LupusColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: widget.onNextPhase,
                child: Text(
                  isSoulStealer ? context.tr('thief_keep_status') : context.tr('thief_stay_thief'),
                  style: const TextStyle(fontSize: 10.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Module Cupidon (Nuit 1) : Sélection multi-cibles en 2 clics directs (sans bouton Valider)
  Widget _buildCupidSection(PlayerModel? selectedTarget) {
    final lover1 = _cupidLover1Id != null ? widget.room.players[_cupidLover1Id] : null;
    final lover2 = _cupidLover2Id != null ? widget.room.players[_cupidLover2Id] : null;

    final String statusText;
    if (lover1 == null) {
      statusText = context.tr('cupid_step1');
    } else if (lover2 == null) {
      statusText = context.tr('cupid_step2', {'name': lover1.name});
    } else {
      statusText = context.tr('cupid_bound', {'p1': lover1.name, 'p2': lover2.name});
    }

    return Column(
      key: ValueKey('action_cupid_${_cupidLover1Id ?? "none"}_${_cupidLover2Id ?? "none"}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: const Color(0x22FF70A6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFF70A6).withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Text('🏹', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFB3D1),
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (selectedTarget != null && selectedTarget.isAlive) {
                    _handleCupidSelection(selectedTarget.id);
                  }
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: lover1 != null
                        ? const Color(0xFFFF70A6).withValues(alpha: 0.2)
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: lover1 != null
                          ? const Color(0xFFFF70A6)
                          : LupusColors.border.withValues(alpha: 0.5),
                      width: lover1 != null ? 1.4 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFFF70A6)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          lover1 != null ? lover1.name : context.tr('add_lover_1'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: lover1 != null ? FontWeight.w900 : FontWeight.w600,
                            color: lover1 != null ? Colors.white : LupusColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (selectedTarget != null && selectedTarget.isAlive) {
                    _handleCupidSelection(selectedTarget.id);
                  }
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: lover2 != null
                        ? const Color(0xFFFF70A6).withValues(alpha: 0.2)
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: lover2 != null
                          ? const Color(0xFFFF70A6)
                          : LupusColors.border.withValues(alpha: 0.5),
                      width: lover2 != null ? 1.4 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite_border_rounded, size: 14, color: Color(0xFFFF70A6)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          lover2 != null ? lover2.name : context.tr('add_lover_2'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: lover2 != null ? FontWeight.w900 : FontWeight.w600,
                            color: lover2 != null ? Colors.white : LupusColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Module Pyromane : Asperger d'huile ou brûler
  Widget _buildPyromaniacSection(PlayerModel? selectedTarget) {
    final dousedPlayers = widget.room.alivePlayers.where((p) => p.isDoused).toList();
    final isTargetDoused = selectedTarget?.isDoused == true;

    return Row(
      key: ValueKey('action_pyromaniac_${selectedTarget?.id ?? "none"}'),
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4800),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (selectedTarget != null && selectedTarget.isAlive && !isTargetDoused)
                  ? () => widget.onPyromaniacDouse?.call(selectedTarget.id)
                  : null,
              icon: const Icon(Icons.water_drop_rounded, size: 14),
              label: Text(
                selectedTarget != null
                    ? (isTargetDoused ? context.tr('doused_target', {'name': selectedTarget.name}) : context.tr('douse_target', {'name': selectedTarget.name}))
                    : context.tr('douse_select'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: dousedPlayers.isNotEmpty
                ? () {
                    HapticFeedback.heavyImpact();
                    widget.onPyromaniacIgnite?.call();
                  }
                : null,
            icon: const Icon(Icons.local_fire_department_rounded, size: 15),
            label: Text(
              context.tr('ignite_count', {'count': '${dousedPlayers.length}'}),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 40,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: LupusColors.textMuted,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: widget.onPyromaniacPass,
            child: Text(context.tr('pass'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  /// Module Joueur de Flûte : Sélection multi-cibles en 2 clics directs (sans bouton Valider)
  Widget _buildPiperSection(PlayerModel? selectedTarget) {
    final target1 = _piperTarget1Id != null ? widget.room.players[_piperTarget1Id] : null;
    final target2 = _piperTarget2Id != null ? widget.room.players[_piperTarget2Id] : null;
    final uncharmedLiving = widget.room.alivePlayers.where((p) => !p.isCharmed).toList();

    final String statusText;
    if (uncharmedLiving.length <= 1) {
      statusText = context.tr('piper_step_last');
    } else if (target1 == null) {
      statusText = context.tr('piper_step1');
    } else if (target2 == null) {
      statusText = context.tr('piper_step2', {'name': target1.name});
    } else {
      statusText = context.tr('piper_bound', {'p1': target1.name, 'p2': target2.name});
    }

    return Column(
      key: ValueKey('action_piper_${_piperTarget1Id ?? "none"}_${_piperTarget2Id ?? "none"}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: const Color(0x2206D6A0),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF06D6A0).withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Text('🪈', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6EE7B7),
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (selectedTarget != null && selectedTarget.isAlive && !selectedTarget.isCharmed) {
                    _handlePiperSelection(selectedTarget.id);
                  }
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: target1 != null
                        ? const Color(0xFF06D6A0).withValues(alpha: 0.2)
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: target1 != null
                          ? const Color(0xFF06D6A0)
                          : LupusColors.border.withValues(alpha: 0.5),
                      width: target1 != null ? 1.4 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note_rounded, size: 14, color: Color(0xFF06D6A0)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          target1 != null ? target1.name : context.tr('target_1'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: target1 != null ? FontWeight.w900 : FontWeight.w600,
                            color: target1 != null ? const Color(0xFF06D6A0) : LupusColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (uncharmedLiving.length > 1) ...[
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (selectedTarget != null && selectedTarget.isAlive && !selectedTarget.isCharmed) {
                      _handlePiperSelection(selectedTarget.id);
                    }
                  },
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: target2 != null
                        ? const Color(0xFF06D6A0).withValues(alpha: 0.2)
                        : Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: target2 != null
                            ? const Color(0xFF06D6A0)
                            : LupusColors.border.withValues(alpha: 0.5),
                        width: target2 != null ? 1.4 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.music_note_outlined, size: 14, color: Color(0xFF06D6A0)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            target2 != null ? target2.name : context.tr('target_2'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: target2 != null ? FontWeight.w900 : FontWeight.w600,
                              color: target2 != null ? const Color(0xFF06D6A0) : LupusColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Module Petite Fille : Télémétrie de la chasse des loups et espionnage secret
  Widget _buildLittleGirlSection(PlayerModel? selectedTarget) {
    final rawVictimId = _wolfVictimId ?? widget.room.nightVictimId;
    final victimPlayer = (rawVictimId != null && rawVictimId.isNotEmpty)
        ? widget.room.players[rawVictimId]
        : null;
    final hasVictim = victimPlayer != null &&
        victimPlayer.isAlive &&
        !DeathRegistryService.instance.isDead(rawVictimId!);

    final String statusText;
    final Color bannerBorderColor;
    final Color bannerBgColor;

    if (_littleGirlEyesClosed) {
      statusText = context.tr('little_girl_eyes_closed');
      bannerBorderColor = const Color(0xFF64748B);
      bannerBgColor = const Color(0x2264748B);
    } else if (hasVictim) {
      statusText = context.tr('little_girl_prey_detected', {'name': victimPlayer.name});
      bannerBorderColor = const Color(0xFFFF2A55);
      bannerBgColor = const Color(0x22FF2A55);
    } else {
      statusText = context.tr('little_girl_wolves_deliberating');
      bannerBorderColor = const Color(0xFFFFC6FF);
      bannerBgColor = const Color(0x22FFC6FF);
    }

    return Column(
      key: ValueKey('action_little_girl_${_littleGirlEyesClosed}_${rawVictimId ?? "none"}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            color: bannerBgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bannerBorderColor.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Text(_littleGirlEyesClosed ? '🙈' : (hasVictim ? '👀' : '👂'), style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _littleGirlEyesClosed
                        ? const Color(0xFF94A3B8)
                        : (hasVictim ? const Color(0xFFFFE4E6) : const Color(0xFFF5D0FE)),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!_littleGirlEyesClosed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(
              color: const Color(0x2BFF0033),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x55FF2A4B)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFFF8080)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    context.tr('little_girl_peeking_warning'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFD1D1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _littleGirlEyesClosed
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFFA855F7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final nextState = !_littleGirlEyesClosed;
                    setState(() {
                      _littleGirlEyesClosed = nextState;
                    });
                    widget.onLittleGirlToggleEyes?.call(nextState);
                  },
                  icon: Icon(
                    _littleGirlEyesClosed ? Icons.visibility_rounded : Icons.hearing_rounded,
                    size: 15,
                  ),
                  label: Text(
                    _littleGirlEyesClosed
                        ? context.tr('little_girl_open_eyes')
                        : context.tr('little_girl_keep_spying'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: LupusColors.textMuted,
                  side: BorderSide(color: LupusColors.border.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  setState(() {
                    _littleGirlEyesClosed = true;
                  });
                  widget.onLittleGirlToggleEyes?.call(true);
                },
                icon: const Icon(Icons.visibility_off_rounded, size: 14),
                label: Text(
                  context.tr('little_girl_close_eyes'),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Module Le Renard : Flairer un groupe de 3 joueurs adjacents ou passer son tour
  Widget _buildFoxSection(PlayerModel? selectedTarget) {
    final foxActive = widget.room.expandedRolesState.foxPowerActive &&
        !widget.room.expandedRolesState.ancientPowerLost;

    if (!foxActive) {
      return Container(
        key: const ValueKey('action_fox_exhausted'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x2264748B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF64748B).withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Text('🦊', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('fox_lost_power'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    final seatingOrder = widget.room.seatingOrder.isNotEmpty
        ? widget.room.seatingOrder
        : widget.room.players.keys.toList();
    final aliveIds = seatingOrder
        .where((id) =>
            widget.room.players[id]?.isAlive == true &&
            !DeathRegistryService.instance.isDead(id))
        .toList();

    String trioInfo = '';
    if (selectedTarget != null && selectedTarget.isAlive) {
      final targetIdx = aliveIds.indexOf(selectedTarget.id);
      if (targetIdx != -1) {
        final n = aliveIds.length;
        final leftName = widget.room.players[aliveIds[(targetIdx - 1 + n) % n]]?.name ?? '';
        final rightName = widget.room.players[aliveIds[(targetIdx + 1) % n]]?.name ?? '';
        trioInfo = ' ($leftName, ${selectedTarget.name}, $rightName)';
      }
    }

    final actionRow = Row(
      key: ValueKey('action_fox_${selectedTarget?.id ?? "none"}'),
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFB8500),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (selectedTarget != null && selectedTarget.isAlive)
                  ? () => widget.onFoxSniff?.call(selectedTarget.id)
                  : null,
              icon: const Icon(Icons.pest_control_rounded, size: 15),
              label: Text(
                selectedTarget != null
                    ? context.tr('fox_sniff_target', {'name': '${selectedTarget.name}$trioInfo'})
                    : context.tr('fox_select_target'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 40,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: LupusColors.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: widget.onFoxPass,
            child: Text(
              context.tr('fox_pass'),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
    );

    final lastCheck = widget.room.expandedRolesState.lastFoxCheckResult;
    if (lastCheck == true) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x33DC2626),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.6)),
            ),
            child: const Row(
              children: [
                Text('🐾', style: TextStyle(fontSize: 14)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Odeur de loup détectée ! Au moins un loup se cache dans le groupe flairé.',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFFFF8B8B), fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          actionRow,
        ],
      );
    }

    return actionRow;
  }

  /// Module Loup-Garou Blanc : Élimination solitaire d'un loup ou passer son tour
  Widget _buildWhiteWerewolfSection(PlayerModel? selectedTarget) {
    final isTargetWolf = selectedTarget != null &&
        selectedTarget.isAlive &&
        selectedTarget.id != widget.currentUserId &&
        (selectedTarget.role.isEvil || selectedTarget.id == widget.room.infectedPlayerId);

    return Row(
      key: ValueKey('action_white_wolf_${selectedTarget?.id ?? "none"}'),
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE0AAFF),
                foregroundColor: const Color(0xFF240046),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isTargetWolf
                  ? () => widget.onWhiteWolfDevour?.call(selectedTarget.id)
                  : null,
              icon: const Icon(Icons.brightness_7_rounded, size: 15),
              label: Text(
                isTargetWolf
                    ? context.tr('white_wolf_devour_target', {'name': selectedTarget.name})
                    : context.tr('white_wolf_select_target'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 40,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: LupusColors.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: widget.onWhiteWolfPass,
            child: Text(
              context.tr('white_wolf_pass'),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}



