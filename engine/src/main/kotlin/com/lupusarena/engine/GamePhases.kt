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
