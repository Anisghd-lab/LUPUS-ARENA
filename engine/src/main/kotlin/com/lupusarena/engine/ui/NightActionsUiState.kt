package com.lupusarena.engine.ui

/**
 * État d'un bouton d'action nocturne pour l'UI mobile (Compose / Android / Flutter).
 */
data class ActionBoutonState(
    val texte: String,
    val isEnabled: Boolean,
    val estVisible: Boolean
)

/**
 * Modèle d'état complet pour l'écran nocturne actif d'un joueur à rôle.
 */
data class EcranNuitUiState(
    val titrePhase: String,
    val boutonPrimaire: ActionBoutonState,   // Potion de vie OU Vision
    val boutonSecondaire: ActionBoutonState, // Potion de mort OU Inactif
    val boutonPasser: ActionBoutonState      // Passer le tour / Ne rien faire
)
