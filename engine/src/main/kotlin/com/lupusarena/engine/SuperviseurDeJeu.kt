package com.lupusarena.engine

/**
 * Superviseur Central de Jeu (State Machine Guardian).
 * Orchestre les cycles, valide les transitions de phase, exécute les votes et
 * propage la révélation publique du rôle d'origine (roleInitial) dès tout décès.
 */
class SuperviseurDeJeu(
    val joueurs: MutableList<Joueur>
) {
    val agentSurveillance: AgentSurveillance = AgentSurveillance(joueurs)

    var phaseActuelle: PhaseJeu = PhaseJeu.EN_ATTENTE
        private set

    var tourNumero: Int = 0
        private set

    private var actionNuitEnCours = ActionNuit()
    private val votesDuVillage = mutableMapOf<String, String>()

    // Callbacks d'événements pour l'UI, Firebase ou les logs
    var onPhaseChanged: ((PhaseJeu) -> Unit)? = null
    var onJournalEvent: ((String) -> Unit)? = null
    var onGameOver: ((IssuePartie) -> Unit)? = null
    var onDiffuserCarteRetournee: ((RevelationCarteEvent) -> Unit)? = null
    var onJoueurSilence: ((JoueurSilenceEvent) -> Unit)? = null

    init {
        // Câblage de l'arbitrage terminal
        agentSurveillance.onStateChangedListener = { issue ->
            if (issue != IssuePartie.EN_COURS && phaseActuelle != PhaseJeu.TERMINEE) {
                phaseActuelle = PhaseJeu.TERMINEE
                onPhaseChanged?.invoke(phaseActuelle)
                onGameOver?.invoke(issue)
            }
        }

        // Câblage de la révélation publique du rôle d'origine
        agentSurveillance.onCarteReveleeListener = { event ->
            onJournalEvent?.invoke("Mort de ${event.joueurNom} : sa carte se retourne... C'était un(e) ${event.roleRevele} (${event.camp}) !")
            onDiffuserCarteRetournee?.invoke(event)
        }
    }

    // ==========================================
    // GESTION DES CYCLES ET DES PHASES
    // ==========================================

    fun lancerPartie() {
        if (phaseActuelle != PhaseJeu.EN_ATTENTE) return
        if (joueurs.size < 4) {
            onJournalEvent?.invoke("Nombre insuffisant de joueurs (minimum 4 requis).")
            return
        }
        tourNumero = 1
        onJournalEvent?.invoke("--- Début de la partie (Tour $tourNumero) ---")
        passerANuit()
    }

    private fun passerANuit() {
        if (agentSurveillance.isGameOver) return
        actionNuitEnCours = ActionNuit()
        val voyanteVivante = joueurs.any { it.estEnVie && it.roleActif == Role.VOYANTE }
        if (voyanteVivante && agentSurveillance.gestionnaireVoyante.peutSonder) {
            changerPhase(PhaseJeu.NUIT_VOYANTE)
        } else {
            passerAuxLoups()
        }
    }

    private fun passerAuxLoups() {
        if (agentSurveillance.isGameOver) return
        changerPhase(PhaseJeu.NUIT_LOUPS)
    }

    private fun passerALaSorciere() {
        if (agentSurveillance.isGameOver) return
        val sorciere = joueurs.firstOrNull { it.estEnVie && it.roleActif == Role.SORCIERE }
        val aDesPotions = sorciere != null && (sorciere.potionsVie > 0 || sorciere.potionsMort > 0 || agentSurveillance.gestionnaireSorciere.aEncoreDesPotions)
        if (sorciere != null && aDesPotions) {
            changerPhase(PhaseJeu.NUIT_SORCIERE)
        } else {
            resoudreNuitEtPasserALaube()
        }
    }

    // ==========================================
    // INTERCEPTION DES ACTIONS DE NUIT
    // ==========================================

    fun actionVoyante(voyanteId: String, cibleId: String): Role? {
        if (phaseActuelle != PhaseJeu.NUIT_VOYANTE || agentSurveillance.isGameOver) return null
        val roleVu = agentSurveillance.executerSondageVoyante(voyanteId, cibleId)
        if (roleVu != null) {
            actionNuitEnCours.cibleVoyanteInspecteeId = cibleId
            passerAuxLoups()
        }
        return roleVu
    }

    fun actionVoteLoup(cibleId: String): Boolean {
        if (phaseActuelle != PhaseJeu.NUIT_LOUPS || agentSurveillance.isGameOver) return false
        val cible = joueurs.find { it.id == cibleId && it.estEnVie && !it.roleInitial.estLoup && it.camp != Camp.LOUPS } ?: return false

        actionNuitEnCours.cibleLoupsId = cible.id
        passerALaSorciere()
        return true
    }

    fun actionVoteLoup(loupId: String, cibleId: String): Boolean {
        if (phaseActuelle != PhaseJeu.NUIT_LOUPS || agentSurveillance.isGameOver) return false
        val loup = joueurs.find { it.id == loupId && it.estEnVie && it.roleInitial.estLoup } ?: return false
        val cible = joueurs.find { it.id == cibleId && it.estEnVie && !it.roleInitial.estLoup && it.camp != Camp.LOUPS } ?: return false

        actionNuitEnCours.cibleLoupsId = cible.id
        return true
    }

    fun actionFaireTaireJoueur(loupId: String, cibleId: String): Boolean {
        if (phaseActuelle != PhaseJeu.NUIT_LOUPS || agentSurveillance.isGameOver) return false
        val loup = joueurs.find { it.id == loupId && it.estEnVie && it.roleInitial.estLoup } ?: return false
        val cible = joueurs.find { it.id == cibleId && it.estEnVie && !it.roleInitial.estLoup } ?: return false

        // Ne peut pas bâillonner la cible qui est déjà choisie pour mourir cette nuit
        if (cible.id == actionNuitEnCours.cibleLoupsId) return false

        actionNuitEnCours.cibleSilenceId = cible.id
        return true
    }

    fun validerFinTourLoups() {
        if (phaseActuelle == PhaseJeu.NUIT_LOUPS && !agentSurveillance.isGameOver) {
            passerALaSorciere()
        }
    }

    fun actionSorciereSauver(sorciereId: String): Boolean {
        if (phaseActuelle != PhaseJeu.NUIT_SORCIERE || agentSurveillance.isGameOver) return false
        val sorciere = joueurs.find { it.id == sorciereId && it.estEnVie && it.roleActif == Role.SORCIERE } ?: return false
        if (sorciere.potionsVie <= 0) return false

        actionNuitEnCours.cibleSorciereVieSauvee = true
        sorciere.potionsVie--
        agentSurveillance.gestionnaireSorciere.consommerPotionVie()
        resoudreNuitEtPasserALaube()
        return true
    }

    fun actionSorcierePoison(sorciereId: String, cibleId: String): Boolean {
        if (phaseActuelle != PhaseJeu.NUIT_SORCIERE || agentSurveillance.isGameOver) return false
        val sorciere = joueurs.find { it.id == sorciereId && it.estEnVie && it.roleActif == Role.SORCIERE } ?: return false
        val cible = joueurs.find { it.id == cibleId && it.estEnVie } ?: return false
        if (sorciere.potionsMort <= 0) return false

        actionNuitEnCours.cibleSorcierePoisonId = cible.id
        sorciere.potionsMort--
        agentSurveillance.gestionnaireSorciere.consommerPotionMort()
        resoudreNuitEtPasserALaube()
        return true
    }

    fun passerTourSorciere() {
        if (phaseActuelle == PhaseJeu.NUIT_SORCIERE && !agentSurveillance.isGameOver) {
            resoudreNuitEtPasserALaube()
        }
    }

    // ==========================================
    // RÉSOLUTION DE LA NUIT & PASSAGE AU JOUR
    // ==========================================

    private fun resoudreNuitEtPasserALaube() {
        changerPhase(PhaseJeu.AUBE_BILAN)
        val mortsAExecuter = mutableSetOf<String>()

        val cibleLoups = actionNuitEnCours.cibleLoupsId
        if (cibleLoups != null && !actionNuitEnCours.cibleSorciereVieSauvee) {
            mortsAExecuter.add(cibleLoups)
        }

        val ciblePoison = actionNuitEnCours.cibleSorcierePoisonId
        if (ciblePoison != null) {
            mortsAExecuter.add(ciblePoison)
        }

        // Exécution groupée et révélation automatique des rôles d'origine
        agentSurveillance.declarerMorts(mortsAExecuter)

        // Application du bâillon si la cible a survécu à la nuit
        val cibleSilenceId = actionNuitEnCours.cibleSilenceId
        if (cibleSilenceId != null && cibleSilenceId !in mortsAExecuter) {
            val victimeSilence = joueurs.find { it.id == cibleSilenceId && it.estEnVie }
            if (victimeSilence != null) {
                victimeSilence.estReduitAuSilence = true
                onJournalEvent?.invoke("${victimeSilence.nom} a été terrorisé cette nuit : gorge nouée, il ne pourra pas parler aujourd'hui !")
                onJoueurSilence?.invoke(JoueurSilenceEvent(victimeSilence.id, victimeSilence.nom, tourNumero))
            }
        }

        if (!agentSurveillance.isGameOver) {
            changerPhase(PhaseJeu.JOUR_DEBAT)
        }
    }

    // ==========================================
    // GESTION DES VOTES DU JOUR
    // ==========================================

    fun ouvrirVotesVillage() {
        if (phaseActuelle == PhaseJeu.JOUR_DEBAT && !agentSurveillance.isGameOver) {
            votesDuVillage.clear()
            changerPhase(PhaseJeu.JOUR_VOTE)
        }
    }

    fun enregistrerVote(votantId: String, cibleId: String) {
        if (phaseActuelle != PhaseJeu.JOUR_VOTE || agentSurveillance.isGameOver) return
        val votant = joueurs.find { it.id == votantId && it.estEnVie } ?: return
        val cible = joueurs.find { it.id == cibleId && it.estEnVie } ?: return

        votesDuVillage[votant.id] = cible.id

        val totalVivants = joueurs.count { it.estEnVie }
        if (votesDuVillage.size >= totalVivants) {
            depouillerVotes()
        }
    }

    private fun depouillerVotes() {
        changerPhase(PhaseJeu.CREPUSCULE_BILAN)

        val compte = mutableMapOf<String, Int>()
        votesDuVillage.values.forEach { cibleId ->
            compte[cibleId] = (compte[cibleId] ?: 0) + 1
        }

        val maxVoix = compte.values.maxOrNull() ?: 0
        val majoritaires = compte.filter { it.value == maxVoix }.keys

        if (majoritaires.size == 1) {
            val condamneId = majoritaires.first()
            agentSurveillance.declarerMort(condamneId)
        } else {
            onJournalEvent?.invoke("Égalité des voix : aucun joueur n'est exécuté.")
        }

        // Le silence prend fin à l'issue de la journée de vote
        agentSurveillance.reinitialiserSilences()

        if (!agentSurveillance.isGameOver) {
            tourNumero++
            onJournalEvent?.invoke("--- Nuit $tourNumero ---")
            passerANuit()
        }
    }

    private fun changerPhase(nouvellePhase: PhaseJeu) {
        phaseActuelle = nouvellePhase
        onPhaseChanged?.invoke(nouvellePhase)
    }
}
