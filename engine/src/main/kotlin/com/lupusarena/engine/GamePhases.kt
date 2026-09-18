package com.lupusarena.engine

/**
 * Cycle de vie et phases autoritaires du jeu de Loup-Garou.
 */
enum class PhaseJeu {
    EN_ATTENTE,
    NUIT_VOYANTE,
    NUIT_LOUPS,
    NUIT_SORCIERE,
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
        PhaseJeu.NUIT_VOYANTE -> 1
        PhaseJeu.NUIT_LOUPS -> 2
        PhaseJeu.NUIT_SORCIERE -> 3
        PhaseJeu.AUBE_BILAN -> 4
        else -> 0
    }

val PhaseJeu.isNuit: Boolean
    get() = this == PhaseJeu.NUIT_VOYANTE ||
            this == PhaseJeu.NUIT_LOUPS ||
            this == PhaseJeu.NUIT_SORCIERE ||
            this == PhaseJeu.AUBE_BILAN
