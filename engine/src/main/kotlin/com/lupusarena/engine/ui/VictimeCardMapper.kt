package com.lupusarena.engine.ui

import com.lupusarena.engine.Joueur
import com.lupusarena.engine.determinerRoleVisiblePar

data class VictimeCardUiState(
    val nom: String,
    val roleAfficheTexte: String,
    val iconeEstLoup: Boolean,
    val estCiblable: Boolean
)

object VictimeCardMapper {
    fun preparerVictimeCardUi(
        cible: Joueur,
        joueurConnecte: Joueur
    ): VictimeCardUiState {
        val roleTexte = cible.determinerRoleVisiblePar(joueurConnecte)
        val iconeLoup = cible.roleInitial.estLoup

        // Sécurité : un loup ne peut PAS être ciblé par un autre loup pendant la nuit des loups
        val estCiblable = if (joueurConnecte.roleInitial.estLoup && cible.roleInitial.estLoup) {
            false // Membre du même clan, non attaquable la nuit commune
        } else {
            cible.estEnVie
        }

        return VictimeCardUiState(
            nom = cible.nom,
            roleAfficheTexte = roleTexte,
            iconeEstLoup = iconeLoup,
            estCiblable = estCiblable
        )
    }
}

fun preparerVictimeCardUi(
    cible: Joueur,
    joueurConnecte: Joueur
): VictimeCardUiState = VictimeCardMapper.preparerVictimeCardUi(cible, joueurConnecte)
