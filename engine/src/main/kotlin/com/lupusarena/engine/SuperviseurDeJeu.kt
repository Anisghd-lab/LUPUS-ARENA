package com.lupusarena.engine

/**
 * Superviseur Central de Jeu (State Machine Guardian).
 * Orchestre les cycles, valide les transitions de phase, exécute les votes et
 * propage la révélation publique du rôle d'origine (roleInitial) dès tout décès.
 */
class SuperviseurDeJeu(
    joueurs: List<Joueur>,
    var roomId: String = "room-default"
) {
    val joueurs: MutableList<Joueur> = joueurs.toMutableList()

    val agentSurveillance: AgentSurveillance = AgentSurveillance(this.joueurs)

    var phaseActuelle: PhaseJeu = PhaseJeu.EN_ATTENTE
        private set

    var tourNumero: Int = 0
        private set

    var actionNuitEnCours = ActionNuit()
        internal set
    private val votesDuVillage = mutableMapOf<String, String>()

    var timerActuelSecondes: Int = 0
        get() = when (phaseActuelle) {
            PhaseJeu.JOUR_VOTE -> dureeVoteSecondes
            PhaseJeu.CAPITAINE_SUCCESSION -> dureeSuccessionCapitaineSecondes
            PhaseJeu.NUIT_SORCIERE -> dureeSorciereSecondes
            else -> field
        }

    val votesActuels: Map<String, String>
        get() = votesDuVillage.toMap()

    val dureeSuccessionCapitaineSecondes: Int = 10
    val dureeSorciereSecondes: Int = 15

    var pendingCapitaineId: String? = null
        private set
    private var actionApresSuccession: (() -> Unit)? = null

    var bilanPartie: BilanPartie? = null
        private set

    // Callbacks d'événements pour l'UI, Firebase ou les logs
    var onPhaseChanged: ((PhaseJeu) -> Unit)? = null
    var onJournalEvent: ((String) -> Unit)? = null
    var onGameOver: ((IssuePartie) -> Unit)? = null
    var onBilanPartie: ((BilanPartie) -> Unit)? = null
    var onCapitaineSuccession: ((CapitaineSuccessionEvent) -> Unit)? = null
    var onCapitaineAgonie: ((Joueur) -> Unit)? = null
    var onDiffuserCarteRetournee: ((RevelationCarteEvent) -> Unit)? = null
    var onJoueurSilence: ((JoueurSilenceEvent) -> Unit)? = null
    var onMortInstantanee: ((MortInstantaneeEvent) -> Unit)? = null
    var onEmissionFirebase: ((path: String, value: Any) -> Unit)? = null

    var gestionnaireDebat: GestionnaireDebat? = null
        private set

    init {
        // Câblage de l'arbitrage terminal
        agentSurveillance.onStateChangedListener = { issue ->
            if (issue != IssuePartie.EN_COURS && phaseActuelle != PhaseJeu.TERMINEE) {
                terminerPartie(issue)
            }
        }

        // Câblage de la mort instantanée avec diffusion temps réel
        agentSurveillance.onMortInstantaneeListener = { event ->
            onJournalEvent?.invoke("ÉLIMINATION : ${event.joueurNom} vient de mourir ! Sa carte se retourne : c'était un(e) ${event.roleAffiche.nomAffiche}.")
            diffuserFlipCarteTousJoueurs(event)
        }

        // Câblage de la révélation publique du rôle d'origine
        agentSurveillance.onCarteReveleeListener = { event ->
            onJournalEvent?.invoke("Mort de ${event.joueurNom} : sa carte se retourne... C'était un(e) ${event.roleRevele} (${event.camp}) !")
            onDiffuserCarteRetournee?.invoke(event)
        }
    }

    fun diffuserFlipCarteTousJoueurs(event: MortInstantaneeEvent) {
        onMortInstantanee?.invoke(event)
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
            onEmissionFirebase?.invoke("/rooms/$roomId/currentPhase", PhaseJeu.NUIT_SORCIERE.name)
            onEmissionFirebase?.invoke("/rooms/$roomId/timerSeconds", dureeSorciereSecondes)
            actionNuitEnCours.cibleLoupsId?.let { victimId ->
                onEmissionFirebase?.invoke("/rooms/$roomId/nightVictimId", victimId)
            }
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

        if (actionNuitEnCours.cibleSilenceId == cible.id) {
            actionNuitEnCours.cibleSilenceId = null
        }
        actionNuitEnCours.cibleLoupsId = cible.id
        return true
    }

    fun actionVoteLoup(loupId: String, cibleId: String): Boolean {
        if (phaseActuelle != PhaseJeu.NUIT_LOUPS || agentSurveillance.isGameOver) return false
        if (!joueurs.any { it.id == loupId && it.estEnVie && it.roleInitial.estLoup }) return false
        val cible = joueurs.find { it.id == cibleId && it.estEnVie && !it.roleInitial.estLoup && it.camp != Camp.LOUPS } ?: return false

        if (actionNuitEnCours.cibleSilenceId == cible.id) {
            actionNuitEnCours.cibleSilenceId = null
        }
        actionNuitEnCours.cibleLoupsId = cible.id
        return true
    }

    fun actionFaireTaireJoueur(cibleId: String): Boolean {
        if (phaseActuelle != PhaseJeu.NUIT_LOUPS || agentSurveillance.isGameOver) return false
        val cible = joueurs.find { it.id == cibleId && it.estEnVie } ?: return false
        if (cible.id == actionNuitEnCours.cibleLoupsId) return false

        actionNuitEnCours.cibleSilenceId = cible.id
        return true
    }

    fun actionFaireTaireJoueur(loupId: String, cibleId: String): Boolean {
        if (phaseActuelle != PhaseJeu.NUIT_LOUPS || agentSurveillance.isGameOver) return false
        if (!joueurs.any { it.id == loupId && it.estEnVie && it.roleInitial.estLoup }) return false
        val cible = joueurs.find { it.id == cibleId && it.estEnVie } ?: return false

        // Ne peut pas bâillonner la cible qui est déjà choisie pour mourir cette nuit
        if (cible.id == actionNuitEnCours.cibleLoupsId) return false

        actionNuitEnCours.cibleSilenceId = cible.id
        return true
    }

    fun validerFinTourLoups(): Boolean {
        if (phaseActuelle != PhaseJeu.NUIT_LOUPS || agentSurveillance.isGameOver) return false

        val vivants = joueurs.filter { it.estEnVie }
        val doubleActionRequise = vivants.size >= 2

        if (doubleActionRequise) {
            val cibleLoups = actionNuitEnCours.cibleLoupsId
            val cibleSilence = actionNuitEnCours.cibleSilenceId

            if (cibleLoups == null || cibleSilence == null) {
                return false
            }
            if (cibleLoups == cibleSilence) {
                return false
            }
        } else {
            if (actionNuitEnCours.cibleLoupsId == null) {
                return false
            }
        }

        passerALaSorciere()
        return true
    }

    /**
     * Révèle la victime désignée par la meute STRICTEMENT et UNIQUEMENT à la Sorcière active et vivante.
     */
    fun obtenirVictimeDesLoupsPourSorciere(demandeurId: String): Joueur? {
        if (phaseActuelle != PhaseJeu.NUIT_SORCIERE || agentSurveillance.isGameOver) return null
        if (!joueurs.any { it.id == demandeurId && it.estEnVie && it.roleActif == Role.SORCIERE }) return null
        val victimId = actionNuitEnCours.cibleLoupsId ?: return null
        return joueurs.find { it.id == victimId }
    }

    /**
     * Utilisation de la Potion de Vie par la Sorcière pour sauver la victime des loups.
     * Décrémente strictement potionsVie.
     * cloturerTour = true déclenche immédiatement la transition vers l'aube (pour compatibilité).
     * cloturerTour = false permet à la Sorcière d'enchaîner avec sa Potion de Mort dans la même nuit.
     */
    fun actionSorciereSauver(sorciereId: String, cloturerTour: Boolean = true): Boolean {
        if (phaseActuelle != PhaseJeu.NUIT_SORCIERE || agentSurveillance.isGameOver) return false
        val sorciere = joueurs.find { it.id == sorciereId && it.estEnVie && it.roleActif == Role.SORCIERE } ?: return false
        if (sorciere.potionsVie <= 0) return false
        if (actionNuitEnCours.cibleLoupsId == null) return false
        if (actionNuitEnCours.cibleSorciereVieSauvee) return false // Déjà sauvée cette nuit

        actionNuitEnCours.cibleSorciereVieSauvee = true
        sorciere.potionsVie--
        agentSurveillance.gestionnaireSorciere.consommerPotionVie()
        onJournalEvent?.invoke("La Sorcière a utilisé sa potion de vie.")
        onEmissionFirebase?.invoke("/rooms/$roomId/witchHealed", true)

        if (cloturerTour) {
            validerFinTourSorciere(sorciereId)
        }
        return true
    }

    /**
     * Utilisation de la Potion de Mort par la Sorcière pour éliminer une cible vivante distincte.
     * Décrémente strictement potionsMort.
     */
    fun actionSorcierePoison(sorciereId: String, cibleId: String, cloturerTour: Boolean = true): Boolean {
        if (phaseActuelle != PhaseJeu.NUIT_SORCIERE || agentSurveillance.isGameOver) return false
        val sorciere = joueurs.find { it.id == sorciereId && it.estEnVie && it.roleActif == Role.SORCIERE } ?: return false
        val cible = joueurs.find { it.id == cibleId && it.estEnVie && it.id != sorciereId } ?: return false
        if (sorciere.potionsMort <= 0) return false
        if (actionNuitEnCours.cibleSorcierePoisonId != null) return false // Déjà empoisonné cette nuit

        actionNuitEnCours.cibleSorcierePoisonId = cible.id
        sorciere.potionsMort--
        agentSurveillance.gestionnaireSorciere.consommerPotionMort()
        onJournalEvent?.invoke("La Sorcière a utilisé sa potion de mort.")
        onEmissionFirebase?.invoke("/rooms/$roomId/witchPoisonTargetId", cible.id)

        if (cloturerTour) {
            validerFinTourSorciere(sorciereId)
        }
        return true
    }

    /**
     * Clôture le tour de la Sorcière et déclenche la résolution nocturne vers l'aube.
     */
    fun validerFinTourSorciere(sorciereId: String? = null): Boolean {
        if (phaseActuelle != PhaseJeu.NUIT_SORCIERE || agentSurveillance.isGameOver) return false
        if (sorciereId != null && !joueurs.any { it.id == sorciereId && it.estEnVie && it.roleActif == Role.SORCIERE }) {
            return false
        }
        resoudreNuitEtPasserALaube()
        return true
    }

    fun passerTourSorciere() {
        validerFinTourSorciere()
    }

    fun forcerFinTourSorciereSurExpiration() {
        validerFinTourSorciere()
    }

    fun definirVictimeNocturneDesLoups(cibleId: String) {
        actionNuitEnCours.cibleLoupsId = cibleId
    }

    fun utiliserPotionMortSorciere(sorciereId: String, cibleId: String): Boolean {
        return actionSorcierePoison(sorciereId, cibleId, cloturerTour = false)
    }

    fun cloturerPhaseSorciere() {
        onJournalEvent?.invoke("Clôture de la phase de la Sorcière.")
    }

    // ==========================================
    // RÉSOLUTION DE LA NUIT & PASSAGE AU JOUR
    // ==========================================

    fun resoudreNuitEtPasserALaube() {
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
        val causeMap = mutableMapOf<String, CauseMort>()
        cibleLoups?.let { if (!actionNuitEnCours.cibleSorciereVieSauvee) causeMap[it] = CauseMort.MORSURE_LOUPS }
        ciblePoison?.let { causeMap[it] = CauseMort.POISON_SORCIERE }

        agentSurveillance.declarerMorts(mortsAExecuter, causeMap)

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
            val capitaineMort = mortsAExecuter.mapNotNull { id -> joueurs.find { it.id == id } }
                .firstOrNull { it.estCapitaine || it.roleActif == Role.CAPITAINE }

            if (capitaineMort != null && joueurs.any { it.estEnVie }) {
                demarrerSuccessionCapitaine(capitaineMort.id) {
                    lancerDebatDuVillage()
                }
            } else {
                lancerDebatDuVillage()
            }
        }
    }

    // ==========================================
    // GESTION DU DÉBAT DU VILLAGE
    // ==========================================

    fun lancerDebatDuVillage() {
        changerPhase(PhaseJeu.JOUR_DEBAT)

        gestionnaireDebat = GestionnaireDebat(joueurs).apply {
            onChangementOrateur = { orateur ->
                onJournalEvent?.invoke("C'est à ${orateur.nom} de prendre la parole.")
                // Notifier le serveur audio : ouvrir le micro de cet orateur uniquement
            }

            onOrateurSauteCarMuet = { muet ->
                onJournalEvent?.invoke("${muet.nom} est bâillonné par les loups ! Son tour de parole est sauté.")
                // S'assurer que son micro reste impérativement à 0 / coupé
            }

            onFinDuDebat = {
                onJournalEvent?.invoke("Le temps de débat est écoulé. Place aux votes !")
                ouvrirVotesVillage()
            }
        }

        gestionnaireDebat?.demarrerDebat()
    }

    // Bouton UI "Passer la parole" si l'orateur a fini plus tôt
    fun passerParoleManuelle(joueurId: String) {
        if (phaseActuelle == PhaseJeu.JOUR_DEBAT && gestionnaireDebat?.orateurActuel?.id == joueurId) {
            gestionnaireDebat?.passerAuProchainOrateur()
        }
    }

    val dureeVoteSecondes: Int = 15

    // ==========================================
    // GESTION DES VOTES DU JOUR
    // ==========================================

    /**
     * Ouvre instantanément le scrutin du village (JOUR_VOTE) sans action manuelle ni temps mort.
     * - Réinitialise la table des votes du tour.
     * - Mute la phase actuelle vers PhaseJeu.JOUR_VOTE.
     * - Calibre le chronomètre à 15 secondes.
     * - Émet la mise à jour temps réel vers Firebase (/rooms/{roomId}/currentPhase = "JOUR_VOTE", timerSeconds = 15).
     */
    fun ouvrirVotesVillage() {
        if ((phaseActuelle == PhaseJeu.JOUR_DEBAT || phaseActuelle == PhaseJeu.EN_ATTENTE) && !agentSurveillance.isGameOver) {
            // 1. Réinitialiser la table des votes du tour
            votesDuVillage.clear()

            // 2. Muter phaseActuelle vers PhaseJeu.JOUR_VOTE
            changerPhase(PhaseJeu.JOUR_VOTE)

            // 3. Émettre la mise à jour temps réel vers Firebase
            onEmissionFirebase?.invoke("/rooms/$roomId/currentPhase", PhaseJeu.JOUR_VOTE.name)
            onEmissionFirebase?.invoke("/rooms/$roomId/timerSeconds", dureeVoteSecondes)
            onJournalEvent?.invoke("Ouverture automatique du scrutin du village (JOUR_VOTE) pour exactement $dureeVoteSecondes secondes.")
        }
    }

    /**
     * Déclenche la clôture immédiate du débat en cas d'expiration du temps alloué,
     * assurant la bascule automatique vers JOUR_VOTE sans exiger d'intervention manuelle.
     */
    fun forcerFinDebatSurExpirationTemps() {
        if (phaseActuelle == PhaseJeu.JOUR_DEBAT) {
            onJournalEvent?.invoke("Le temps de débat est écoulé. Clôture automatique et passage au vote.")
            gestionnaireDebat?.forcerFinDebatParExpirationTemps() ?: ouvrirVotesVillage()
        }
    }

    /**
     * Enregistre le vote d'un joueur vivant contre une cible vivante.
     * Dès que l'ensemble des joueurs vivants a voté, déclenche immédiatement le dépouillement
     * et l'exécution sans attendre la fin du compte à rebours.
     */
    fun enregistrerVote(votantId: String, cibleId: String) {
        if (phaseActuelle != PhaseJeu.JOUR_VOTE || agentSurveillance.isGameOver) return
        val votant = joueurs.find { it.id == votantId && it.estEnVie } ?: return
        val cible = joueurs.find { it.id == cibleId && it.estEnVie } ?: return

        votesDuVillage[votant.id] = cible.id
        onJournalEvent?.invoke("${votant.nom} a voté contre ${cible.nom}.")

        val totalVivants = joueurs.count { it.estEnVie }
        // Dépouillement immédiat dès que tous les vivants ont voté
        if (votesDuVillage.size >= totalVivants) {
            depouillerVotesEtExecuter()
        }
    }

    /**
     * Dépouillement immédiat des votes et exécution de la cible majoritaire.
     * - Compte les suffrages (avec voix double du Capitaine si vivant).
     * - En cas de stricte majorité : élimine directement la cible via agentSurveillance.declarerMort.
     * - En cas d'égalité stricte : aucun mort, diffuse l'égalité au journal.
     * - Clôture le jour : réinitialise les silences, incrémente le tour et bascule vers la nuit suivante
     *   (ou termine la partie si condition de victoire atteinte).
     */
    fun depouillerVotesEtExecuter() {
        if (phaseActuelle != PhaseJeu.JOUR_VOTE) return
        changerPhase(PhaseJeu.CREPUSCULE_BILAN)

        var capitaineMortId: String? = null
        if (votesDuVillage.isEmpty()) {
            onJournalEvent?.invoke("Aucun vote exprimé : aucun joueur n'est exécuté.")
        } else {
            val compte = mutableMapOf<String, Int>()
            votesDuVillage.forEach { (votantId, cibleId) ->
                val votant = joueurs.find { it.id == votantId }
                val poids = if (votant != null && (votant.estCapitaine || votant.roleActif == Role.CAPITAINE)) 2 else 1
                compte[cibleId] = (compte[cibleId] ?: 0) + poids
            }

            val maxVoix = compte.values.maxOrNull() ?: 0
            val majoritaires = compte.filter { it.value == maxVoix }.keys

            if (majoritaires.size == 1) {
                val condamneId = majoritaires.first()
                val condamne = joueurs.find { it.id == condamneId }
                onJournalEvent?.invoke("Verdict du village : ${condamne?.nom ?: condamneId} est condamné(e) avec $maxVoix voix !")
                if (condamne != null && (condamne.estCapitaine || condamne.roleActif == Role.CAPITAINE)) {
                    capitaineMortId = condamne.id
                }
                agentSurveillance.declarerMort(condamneId, CauseMort.VOTE_VILLAGE)
            } else {
                onJournalEvent?.invoke("Égalité des voix : aucun joueur n'est exécuté.")
            }
        }

        // Le silence prend fin à l'issue de la journée de vote
        agentSurveillance.reinitialiserSilences()
        gestionnaireDebat = null

        if (!agentSurveillance.isGameOver) {
            val suite = {
                tourNumero++
                onJournalEvent?.invoke("--- Nuit $tourNumero ---")
                passerANuit()
            }
            if (capitaineMortId != null && joueurs.any { it.estEnVie }) {
                demarrerSuccessionCapitaine(capitaineMortId, suite)
            } else {
                suite()
            }
        }
    }

    fun depouillerVotes() = depouillerVotesEtExecuter()

    /**
     * Expiration du temps (15s) alloué au scrutin :
     * Si le timer de 15 secondes expire avant que tout le monde ait voté,
     * dépouille immédiatement les voix enregistrées (les abstentionnistes ne votent pas)
     * et applique l'exécution directement sans attendre.
     */
    fun forcerFinScrutinSurExpiration() {
        if (phaseActuelle == PhaseJeu.JOUR_VOTE && !agentSurveillance.isGameOver) {
            onJournalEvent?.invoke("Chronomètre de 15s écoulé ! Dépouillement immédiat des suffrages exprimés.")
            depouillerVotesEtExecuter()
        }
    }

    // ==========================================
    // MÉTHODES PUBLIQUES & GESTION DES ÉTATS
    // ==========================================

    fun basculerEnPhase(nouvellePhase: PhaseJeu) {
        if (nouvellePhase == PhaseJeu.JOUR_VOTE) {
            votesDuVillage.clear()
        }
        changerPhase(nouvellePhase)
    }

    fun recupererJoueur(id: String): Joueur? = joueurs.find { it.id == id }

    fun eliminerJoueur(joueurId: String, cause: CauseMort = CauseMort.MORSURE_LOUPS) {
        val joueur = joueurs.find { it.id == joueurId } ?: return
        val etaitCapitaine = joueur.estCapitaine || joueur.roleActif == Role.CAPITAINE
        agentSurveillance.declarerMort(joueurId, cause)
        if (etaitCapitaine && joueurs.any { it.estEnVie } && !agentSurveillance.isGameOver) {
            demarrerSuccessionCapitaine(joueurId)
        }
    }

    // ==========================================
    // SUCCESSION DU CAPITAINE (OPTION 1)
    // ==========================================

    /**
     * Déclenche la phase de succession du Capitaine (Option 1).
     * Ouvre une fenêtre d'agonie de 10 secondes.
     */
    fun demarrerSuccessionCapitaine(capitaineId: String, onFin: () -> Unit = {}) {
        val capitaine = joueurs.find { it.id == capitaineId } ?: return
        val vivants = joueurs.filter { it.estEnVie }

        if (vivants.isEmpty() || agentSurveillance.isGameOver) {
            onFin()
            return
        }

        capitaine.estCapitaine = false
        pendingCapitaineId = capitaine.id
        actionApresSuccession = onFin
        changerPhase(PhaseJeu.CAPITAINE_SUCCESSION)

        onEmissionFirebase?.invoke("/rooms/$roomId/currentPhase", PhaseJeu.CAPITAINE_SUCCESSION.name)
        onEmissionFirebase?.invoke("/rooms/$roomId/timerSeconds", dureeSuccessionCapitaineSecondes)
        onEmissionFirebase?.invoke("/rooms/$roomId/pendingCaptainId", capitaine.id)
        onJournalEvent?.invoke("🎖️ Le Capitaine ${capitaine.nom} a péri ! Il dispose de $dureeSuccessionCapitaineSecondes secondes pour désigner son successeur parmi les survivants.")
        onCapitaineAgonie?.invoke(capitaine)
    }

    /**
     * Désignation manuelle d'un héritier par le Capitaine mourant.
     * Mute immédiatement estCapitaine, transmet le vote double (poids = 2) au nouvel élu
     * et reprend le cours normal de la partie.
     */
    fun designerSuccesseurCapitaine(demandeurId: String, heritierId: String): Boolean {
        if (phaseActuelle != PhaseJeu.CAPITAINE_SUCCESSION) return false
        if (pendingCapitaineId != null && pendingCapitaineId != demandeurId) return false

        val defunt = joueurs.find { it.id == demandeurId } ?: return false
        val successeur = joueurs.find { it.id == heritierId && it.estEnVie && it.id != demandeurId } ?: return false

        // Transfert immédiat de l'écharpe
        defunt.estCapitaine = false
        successeur.estCapitaine = true
        pendingCapitaineId = null

        val event = CapitaineSuccessionEvent(
            ancienCapitaineId = defunt.id,
            ancienCapitaineNom = defunt.nom,
            nouveauCapitaineId = successeur.id,
            nouveauCapitaineNom = successeur.nom,
            estPassationAutomatique = false
        )
        onJournalEvent?.invoke("🎖️ Le défunt Capitaine ${defunt.nom} remet son écharpe à ${successeur.nom}, nouveau chef du village !")
        onCapitaineSuccession?.invoke(event)

        onEmissionFirebase?.invoke("/rooms/$roomId/captainId", successeur.id)
        onEmissionFirebase?.invoke("/rooms/$roomId/pendingCaptainId", "")
        onEmissionFirebase?.invoke("/rooms/$roomId/players/${successeur.id}/isCaptain", true)
        onEmissionFirebase?.invoke("/rooms/$roomId/players/${defunt.id}/isCaptain", false)

        val suite = actionApresSuccession
        actionApresSuccession = null
        suite?.invoke()
        return true
    }

    /**
     * Passation automatique d'office sur expiration du chrono de 10s ou déconnexion.
     * Attribue l'écharpe au premier survivant de la liste et poursuit le cycle.
     */
    fun forcerSuccessionCapitaineSurExpiration(): Boolean {
        if (phaseActuelle != PhaseJeu.CAPITAINE_SUCCESSION) return false
        val defuntId = pendingCapitaineId
        val defunt = joueurs.find { it.id == defuntId }
        val vivants = joueurs.filter { it.estEnVie }

        if (vivants.isNotEmpty()) {
            val successeur = vivants.first()
            defunt?.estCapitaine = false
            successeur.estCapitaine = true
            pendingCapitaineId = null

            val event = CapitaineSuccessionEvent(
                ancienCapitaineId = defunt?.id ?: "",
                ancienCapitaineNom = defunt?.nom ?: "Inconnu",
                nouveauCapitaineId = successeur.id,
                nouveauCapitaineNom = successeur.nom,
                estPassationAutomatique = true
            )
            onJournalEvent?.invoke("⏳ Faute de choix du défunt Capitaine, l'écharpe est transmise d'office à ${successeur.nom} !")
            onCapitaineSuccession?.invoke(event)

            onEmissionFirebase?.invoke("/rooms/$roomId/captainId", successeur.id)
            onEmissionFirebase?.invoke("/rooms/$roomId/pendingCaptainId", "")
            onEmissionFirebase?.invoke("/rooms/$roomId/players/${successeur.id}/isCaptain", true)
            if (defunt != null) {
                onEmissionFirebase?.invoke("/rooms/$roomId/players/${defunt.id}/isCaptain", false)
            }
        } else {
            pendingCapitaineId = null
            onJournalEvent?.invoke("⏳ Aucun survivant pour hériter du titre de Capitaine.")
        }

        val suite = actionApresSuccession
        actionApresSuccession = null
        suite?.invoke()
        return true
    }

    // ==========================================
    // FIN DE PARTIE & BILAN (OPTION 3)
    // ==========================================

    /**
     * Clôture définitive de la partie (Option 3).
     * Diffuse l'écran de fin, calcule le BilanPartie et émet les stats vers Firebase.
     */
    fun terminerPartie(issue: IssuePartie) {
        if (phaseActuelle == PhaseJeu.TERMINEE) return
        changerPhase(PhaseJeu.TERMINEE)

        val bilanJoueurs = joueurs.map { j ->
            BilanJoueur(
                id = j.id,
                nom = j.nom,
                roleInitial = j.roleInitial,
                roleActif = j.roleActif,
                camp = j.camp,
                estEnVie = j.estEnVie,
                estCapitaine = j.estCapitaine,
                causeMort = j.causeMort
            )
        }

        val bilan = BilanPartie(
            issue = issue,
            nbTours = tourNumero,
            vainqueurCamp = when (issue) {
                IssuePartie.VICTOIRE_VILLAGE -> Camp.VILLAGE
                IssuePartie.VICTOIRE_LOUPS -> Camp.LOUPS
                else -> null
            },
            joueurs = bilanJoueurs
        )
        bilanPartie = bilan

        val messageVictoire = when (issue) {
            IssuePartie.VICTOIRE_VILLAGE -> "🏆 VICTOIRE DU VILLAGE ! Tous les loups-garous ont été éliminés !"
            IssuePartie.VICTOIRE_LOUPS -> "🐺 VICTOIRE DE LA MEUTE ! Les loups-garous dominent et dévorent le village !"
            IssuePartie.EGALITE -> "⚖️ ÉGALITÉ ! Aucun survivant n'a réchappé au massacre."
            IssuePartie.EN_COURS -> "Partie terminée."
        }
        onJournalEvent?.invoke(messageVictoire)

        onGameOver?.invoke(issue)
        onBilanPartie?.invoke(bilan)

        // Émission Firebase temps réel
        onEmissionFirebase?.invoke("/rooms/$roomId/currentPhase", PhaseJeu.TERMINEE.name)
        onEmissionFirebase?.invoke("/rooms/$roomId/phase", "gameOver")
        onEmissionFirebase?.invoke("/rooms/$roomId/winner", issue.name)
        onEmissionFirebase?.invoke("/rooms/$roomId/timerSeconds", 0)

        // Diffusion du tableau récapitulatif complet
        val recapMap = mapOf(
            "issue" to issue.name,
            "winnerCamp" to (bilan.vainqueurCamp?.name ?: "AUCUN"),
            "nbTours" to tourNumero,
            "totalVivants" to bilan.totalVivants,
            "totalMorts" to bilan.totalMorts,
            "survivantsVillage" to bilan.survivantsVillage,
            "survivantsLoups" to bilan.survivantsLoups,
            "joueurs" to bilanJoueurs.map { bj ->
                mapOf(
                    "id" to bj.id,
                    "nom" to bj.nom,
                    "roleInitial" to bj.roleInitial.name,
                    "roleActif" to bj.roleActif.name,
                    "camp" to bj.camp.name,
                    "estEnVie" to bj.estEnVie,
                    "estCapitaine" to bj.estCapitaine,
                    "causeMort" to (bj.causeMort?.name ?: "AUCUNE")
                )
            }
        )
        onEmissionFirebase?.invoke("/rooms/$roomId/recapTable", recapMap)
    }

    private fun changerPhase(nouvellePhase: PhaseJeu) {
        if (phaseActuelle.isNuit && nouvellePhase.isNuit) {
            if (nouvellePhase.nightOrderIndex < phaseActuelle.nightOrderIndex) {
                onJournalEvent?.invoke("GARDE MONOTONE : Tentative de régression nocturne rejetée ($phaseActuelle -> $nouvellePhase).")
                return
            }
        }
        phaseActuelle = nouvellePhase
        onPhaseChanged?.invoke(nouvellePhase)
    }
}
