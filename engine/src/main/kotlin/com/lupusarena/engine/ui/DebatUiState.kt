package com.lupusarena.engine.ui

/**
 * Modèle d'état UI représentant un participant lors de la ronde de parole du village.
 * Expose l'état du micro et l'indicateur de mutisme forcé (icône micro barré rouge).
 */
data class ParticipantDebatUiState(
    val id: String,
    val nom: String,
    val aLaParole: Boolean,
    val estMuteForce: Boolean,      // Active l'icône micro barré rouge / cadenas
    val iconeMuteVisible: Boolean   // Visible dès que estReduitAuSilence == true
)

/**
 * État global de la ronde de parole du débat du village.
 */
data class TourDeParoleUiState(
    val orateurActuelId: String?,
    val orateurActuelNom: String?,
    val tempsRestantSecondes: Int,
    val participants: List<ParticipantDebatUiState>
)
