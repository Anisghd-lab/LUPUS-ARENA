package com.lupusarena.engine

import com.lupusarena.engine.ui.ParticipantDebatUiState
import com.lupusarena.engine.ui.TourDeParoleUiState

/**
 * Rôle structurel d'un tour de parole dans la ronde de débat du village.
 */
enum class TypeTourParole {
    CAPITAINE_OUVERTURE,
    CORPS_DEBAT,
    CAPITAINE_CLOTURE
}

/**
 * Étape individuelle planifiée dans la file d'attente du débat.
 */
data class EtapeTourParole(
    val joueur: Joueur,
    val type: TypeTourParole
)

/**
 * Gestionnaire du débat et de la ronde de parole du village (`JOUR_DEBAT`).
 *
 * Règle stricte de préséance du Capitaine :
 * - Le Capitaine (ou Maire du village) doit obligatoirement parler DEUX FOIS :
 *   il commence les débats (premier orateur) et il termine les débats (dernier orateur).
 * - Tous les autres villageois vivants et non muets parlent entre ces deux interventions.
 *
 * Gestion des cas limites :
 * - Si le Capitaine est réduit au silence (estReduitAuSilence == true), ses deux tours
 *   de parole (ouverture et fermeture) sont sautés automatiquement sans temps mort et sans bloquer la file.
 * - S'il n'y a pas encore de Capitaine élu ou s'il est mort, la file déroule simplement les vivants non muets de façon standard.
 * - Le passage de parole ("Passer la parole") avance de façon strictement monotone sans cycle infini.
 */
class GestionnaireDebat(
    private val joueurs: List<Joueur>,
    val dureeParoleSecondes: Int = 30
) {
    private var fileDeParole: List<EtapeTourParole> = emptyList()
    private var indexEtape: Int = -1

    var etapeActuelle: EtapeTourParole? = null
        private set

    var orateurActuel: Joueur? = null
        private set

    val estTourCapitaineOuverture: Boolean
        get() = etapeActuelle?.type == TypeTourParole.CAPITAINE_OUVERTURE

    val estTourCapitaineCloture: Boolean
        get() = etapeActuelle?.type == TypeTourParole.CAPITAINE_CLOTURE

    /**
     * File complète ordonnée des tours de parole prévus pour le débat.
     * Si un Capitaine vivant existe : [Capitaine, autres vivants, Capitaine].
     * Sinon : tous les vivants.
     */
    val ordreDeParole: List<Joueur>
        get() = construireFileDeParole().map { it.joueur }

    /**
     * Liste ordonnée des orateurs effectifs qui auront la parole (en sautant les joueurs réduits au silence).
     */
    val orateursEffectifs: List<Joueur>
        get() = construireFileDeParole()
            .filterNot { it.joueur.estReduitAuSilence }
            .map { it.joueur }

    var onChangementOrateur: ((Joueur) -> Unit)? = null
    var onOrateurSauteCarMuet: ((Joueur) -> Unit)? = null
    var onFinDuDebat: (() -> Unit)? = null

    /**
     * Construit dynamiquement la file ordonnée des étapes de parole.
     */
    fun construireFileDeParole(): List<EtapeTourParole> {
        val vivants = joueurs.filter { it.estEnVie }
        val capitaine = vivants.firstOrNull { it.estCapitaine || it.roleActif == Role.CAPITAINE }

        return if (capitaine != null) {
            val autresVivants = vivants.filter { it.id != capitaine.id }
            val file = mutableListOf<EtapeTourParole>()
            file.add(EtapeTourParole(capitaine, TypeTourParole.CAPITAINE_OUVERTURE))
            autresVivants.forEach { file.add(EtapeTourParole(it, TypeTourParole.CORPS_DEBAT)) }
            file.add(EtapeTourParole(capitaine, TypeTourParole.CAPITAINE_CLOTURE))
            file
        } else {
            vivants.map { EtapeTourParole(it, TypeTourParole.CORPS_DEBAT) }
        }
    }

    /**
     * Démarre la ronde de débat en initialisant la file et en désignant le premier orateur valide.
     */
    fun demarrerDebat() {
        fileDeParole = construireFileDeParole()
        indexEtape = -1
        etapeActuelle = null
        orateurActuel = null
        passerAuProchainOrateur()
    }

    /**
     * Passe au prochain orateur dans la file ordonnée.
     * Avance de façon strictement séquentielle :
     * - Saute immédiatement tout joueur réduit au silence en invoquant onOrateurSauteCarMuet sans temps mort.
     * - Clôture le débat dès que la file est épuisée en appelant onFinDuDebat.
     * - Empêche tout cycle infini grâce à une avancée monotone de l'index.
     */
    fun passerAuProchainOrateur() {
        if (fileDeParole.isEmpty()) {
            fileDeParole = construireFileDeParole()
        }

        if (fileDeParole.isEmpty()) {
            etapeActuelle = null
            orateurActuel = null
            onFinDuDebat?.invoke()
            return
        }

        while (true) {
            indexEtape++

            // Fin de la file d'attente -> fin du débat
            if (indexEtape >= fileDeParole.size) {
                etapeActuelle = null
                orateurActuel = null
                onFinDuDebat?.invoke()
                return
            }

            val etape = fileDeParole[indexEtape]
            val candidat = etape.joueur

            // Sécurité : joueur éliminé entre-temps
            if (!candidat.estEnVie) {
                continue
            }

            // SAUT AUTOMATIQUE SI LE JOUEUR EST RÉDUIT AU SILENCE
            if (candidat.estReduitAuSilence) {
                onOrateurSauteCarMuet?.invoke(candidat)
                // Poursuit immédiatement la boucle vers le candidat suivant sans temps mort
                continue
            }

            // Orateur valide trouvé
            etapeActuelle = etape
            orateurActuel = candidat
            onChangementOrateur?.invoke(candidat)
            return
        }
    }

    /**
     * Force la fin immédiate du débat (ex. expiration du temps alloué)
     * et déclenche directement onFinDuDebat sans temps mort.
     */
    fun forcerFinDebatParExpirationTemps() {
        etapeActuelle = null
        orateurActuel = null
        onFinDuDebat?.invoke()
    }

    /**
     * Génère l'état UI complet pour le client (TourDeParoleUiState).
     * Expose la liste des participants uniques avec leur état de parole/micro,
     * ainsi que les indicateurs d'ouverture et de clôture par le Capitaine.
     */
    fun genererUiState(tempsRestantSecondes: Int = dureeParoleSecondes): TourDeParoleUiState {
        val vivants = joueurs.filter { it.estEnVie }
        val participants = vivants.map { joueur ->
            ParticipantDebatUiState(
                id = joueur.id,
                nom = joueur.nom,
                aLaParole = orateurActuel?.id == joueur.id,
                estMuteForce = joueur.estReduitAuSilence,
                iconeMuteVisible = joueur.estReduitAuSilence,
                estCapitaine = joueur.estCapitaine || joueur.roleActif == Role.CAPITAINE
            )
        }
        return TourDeParoleUiState(
            orateurActuelId = orateurActuel?.id,
            orateurActuelNom = orateurActuel?.nom,
            tempsRestantSecondes = tempsRestantSecondes,
            participants = participants,
            estTourCapitaineOuverture = estTourCapitaineOuverture,
            estTourCapitaineCloture = estTourCapitaineCloture
        )
    }
}
