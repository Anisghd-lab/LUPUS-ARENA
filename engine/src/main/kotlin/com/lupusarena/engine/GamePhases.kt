package com.lupusarena.engine

/**
 * Cycle de vie et phases autoritaires du jeu de Loup-Garou.
 */
enum class PhaseJeu {
    EN_ATTENTE,
    NUIT_VOLEUR,
    NUIT_CUPIDON,
    NUIT_SALVATEUR,
    NUIT_VOYANTE,
    NUIT_LOUPS,
    NUIT_LOUP_NOIR,
    NUIT_SORCIERE,
    NUIT_JOUEUR_DE_FLUTE,
    NUIT_PYROMANE,
    AUBE_BILAN,
    CAPITAINE_SUCCESSION,
    JOUR_DEBAT,
    JOUR_VOTE,
    CREPUSCULE_BILAN,
    TERMINEE
}

/**
 * État volatile des actions enregistrées au cours d'une nuit.
 */
data class ActionNuit(
    var cibleLoupsId: String? = null,
    var cibleSilenceId: String? = null, // Cible bâillonnée par la meute
    var cibleSorcierePoisonId: String? = null,
    var cibleSorciereVieSauvee: Boolean = false,
    var cibleVoyanteInspecteeId: String? = null
)

val PhaseJeu.nightOrderIndex: Int
    get() = when (this) {
        PhaseJeu.NUIT_VOLEUR -> 1
        PhaseJeu.NUIT_CUPIDON -> 2
        PhaseJeu.NUIT_SALVATEUR -> 3
        PhaseJeu.NUIT_VOYANTE -> 4
        PhaseJeu.NUIT_LOUPS -> 5
        PhaseJeu.NUIT_LOUP_NOIR -> 6
        PhaseJeu.NUIT_SORCIERE -> 7
        PhaseJeu.NUIT_JOUEUR_DE_FLUTE -> 8
        PhaseJeu.NUIT_PYROMANE -> 9
        PhaseJeu.AUBE_BILAN -> 10
        else -> 0
    }

val PhaseJeu.isNuit: Boolean
    get() = this == PhaseJeu.NUIT_VOLEUR ||
            this == PhaseJeu.NUIT_CUPIDON ||
            this == PhaseJeu.NUIT_SALVATEUR ||
            this == PhaseJeu.NUIT_VOYANTE ||
            this == PhaseJeu.NUIT_LOUPS ||
            this == PhaseJeu.NUIT_LOUP_NOIR ||
            this == PhaseJeu.NUIT_SORCIERE ||
            this == PhaseJeu.NUIT_JOUEUR_DE_FLUTE ||
            this == PhaseJeu.NUIT_PYROMANE ||
            this == PhaseJeu.AUBE_BILAN
