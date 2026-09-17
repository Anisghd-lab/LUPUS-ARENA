package com.lupusarena.engine

import com.lupusarena.engine.ui.ParticipantDebatUiState
import com.lupusarena.engine.ui.TourDeParoleUiState

/**
 * Gestionnaire du débat et de la ronde de parole du village.
 * Lorsqu'un tour se termine ou qu'un nouvel orateur est sélectionné,
 * il détecte immédiatement si le joueur a estReduitAuSilence == true,
 * saute automatiquement son tour sans temps mort et passe directement au joueur vivant suivant.
 */
class GestionnaireDebat(
    private val joueurs: List<Joueur>,
    val dureeParoleSecondes: Int = 30
) {
    private var indexOrateur: Int = -1

    val ordreDeParole: List<Joueur>
        get() = joueurs.filter { it.estEnVie }

    var orateurActuel: Joueur? = null
        private set

    var onChangementOrateur: ((Joueur) -> Unit)? = null
    var onOrateurSauteCarMuet: ((Joueur) -> Unit)? = null
    var onFinDuDebat: (() -> Unit)? = null

    fun demarrerDebat() {
        indexOrateur = -1
        passerAuProchainOrateur()
    }

    fun passerAuProchainOrateur() {
        val vivants = ordreDeParole
        if (vivants.isEmpty()) {
            orateurActuel = null
            onFinDuDebat?.invoke()
            return
        }

        indexOrateur++

        // Si tout le monde a parlé (ou a été sauté), fin du débat -> ouverture des votes
        if (indexOrateur >= vivants.size) {
            orateurActuel = null
            onFinDuDebat?.invoke()
            return
        }

        val candidat = vivants[indexOrateur]

        // SAUT AUTOMATIQUE SI LE JOUEUR EST RÉDUIT AU SILENCE
        if (candidat.estReduitAuSilence) {
            onOrateurSauteCarMuet?.invoke(candidat)
            // Récursion immédiate : la parole passe directement au suivant sans temps mort
            passerAuProchainOrateur()
            return
        }

        orateurActuel = candidat
        onChangementOrateur?.invoke(candidat)
    }

    fun genererUiState(tempsRestantSecondes: Int = dureeParoleSecondes): TourDeParoleUiState {
        val participants = ordreDeParole.map { joueur ->
            ParticipantDebatUiState(
                id = joueur.id,
                nom = joueur.nom,
                aLaParole = orateurActuel?.id == joueur.id,
                estMuteForce = joueur.estReduitAuSilence,
                iconeMuteVisible = joueur.estReduitAuSilence
            )
        }
        return TourDeParoleUiState(
            orateurActuelId = orateurActuel?.id,
            orateurActuelNom = orateurActuel?.nom,
            tempsRestantSecondes = tempsRestantSecondes,
            participants = participants
        )
    }
}
