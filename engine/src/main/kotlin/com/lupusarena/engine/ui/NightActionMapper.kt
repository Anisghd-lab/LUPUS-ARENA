package com.lupusarena.engine.ui

import com.lupusarena.engine.Joueur
import com.lupusarena.engine.Role

/**
 * Formateur d'état UI dynamique traduisant les quotas de jeu (Sorcière, Voyante)
 * en libellés de boutons explicites et contrôles d'activation (isEnabled).
 */
object NightActionMapper {

    fun construireEtatVoyante(voyante: Joueur): EcranNuitUiState {
        val visions = voyante.visionsRestantes
        val peutAgir = visions > 0 && voyante.roleActif == Role.VOYANTE

        return EcranNuitUiState(
            titrePhase = "Nuit de la Voyante",
            boutonPrimaire = ActionBoutonState(
                texte = "Sonder un joueur ($visions restante${if (visions > 1) "s" else ""})",
                isEnabled = peutAgir,
                estVisible = true
            ),
            boutonSecondaire = ActionBoutonState(texte = "", isEnabled = false, estVisible = false),
            boutonPasser = ActionBoutonState(
                texte = "Passer le tour",
                isEnabled = true,
                estVisible = true
            )
        )
    }

    fun construireEtatSorciere(sorciere: Joueur, victimeDesLoupsNom: String?): EcranNuitUiState {
        val vie = sorciere.potionsVie
        val poison = sorciere.potionsMort
        val aVictime = victimeDesLoupsNom != null
        val estSorciereActive = sorciere.roleActif == Role.SORCIERE

        return EcranNuitUiState(
            titrePhase = "Nuit de la Sorcière",
            boutonPrimaire = ActionBoutonState(
                texte = if (aVictime) "Sauver $victimeDesLoupsNom (Vie: $vie)" else "Sauver (Vie: $vie)",
                isEnabled = vie > 0 && aVictime && estSorciereActive,
                estVisible = true
            ),
            boutonSecondaire = ActionBoutonState(
                texte = "Empoisonner (Mort: $poison)",
                isEnabled = poison > 0 && estSorciereActive,
                estVisible = true
            ),
            boutonPasser = ActionBoutonState(
                texte = "Ne rien faire / Terminer",
                isEnabled = true,
                estVisible = true
            )
        )
    }
}
