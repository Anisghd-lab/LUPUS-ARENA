package com.lupusarena.engine.ui

import com.lupusarena.engine.Joueur

data class EcranNuitLoupsUiState(
    val boutonMordreTexte: String,
    val boutonMordreActif: Boolean,
    val boutonSilenceTexte: String,
    val boutonSilenceActif: Boolean,
    val messageStatut: String
)

object LoupActionMapper {
    fun construireEtat(
        cibleMorsureSelectionnee: Joueur?,
        cibleSilenceSelectionnee: Joueur?
    ): EcranNuitLoupsUiState {
        val cibleMorsureValide = cibleMorsureSelectionnee != null && !cibleMorsureSelectionnee.roleInitial.estLoup
        val cibleSilenceValide = cibleSilenceSelectionnee != null &&
                !cibleSilenceSelectionnee.roleInitial.estLoup &&
                cibleSilenceSelectionnee.id != cibleMorsureSelectionnee?.id

        return EcranNuitLoupsUiState(
            boutonMordreTexte = if (cibleMorsureValide) "Dévorer ${cibleMorsureSelectionnee!!.nom}" else "Choisir une proie",
            boutonMordreActif = cibleMorsureValide,
            boutonSilenceTexte = if (cibleSilenceValide) "Faire taire ${cibleSilenceSelectionnee!!.nom}" else "Réduire au silence",
            boutonSilenceActif = cibleSilenceValide,
            messageStatut = "Concertez-vous avec la meute pour dévorer et museler."
        )
    }
}
