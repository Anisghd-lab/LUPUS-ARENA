package com.lupusarena.engine

/**
 * Agent de surveillance autoritaire (Watcher) reliant l'arbitre, les gestionnaires
 * de rôles et l'état des joueurs.
 * Gère la déchéance de roleActif et la révélation systématique de roleInitial à la mort.
 */
class AgentSurveillance(
    val joueurs: MutableList<Joueur>
) {
    val totalJoueursDepart: Int = joueurs.size
    val gestionnaireSorciere: GestionnaireSorciere = GestionnaireSorciere(totalJoueursDepart)
    val gestionnaireVoyante: GestionnaireVoyante = GestionnaireVoyante(totalJoueursDepart)
    val arbitre: ArbitrePartie = ArbitrePartie(joueurs, gestionnaireSorciere)

    var issueActuelle: IssuePartie = IssuePartie.EN_COURS
        private set

    val isGameOver: Boolean
        get() = issueActuelle != IssuePartie.EN_COURS

    // Listeners pour l'UI, Firebase et le journal
    var onStateChangedListener: ((IssuePartie) -> Unit)? = null
    var onRoleDowngradedListener: ((Joueur, Role) -> Unit)? = null
    var onCarteReveleeListener: ((RevelationCarteEvent) -> Unit)? = null

    init {
        joueurs.forEach { joueur ->
            when (joueur.roleInitial) {
                Role.SORCIERE -> {
                    if (joueur.potionsVie == 0 && joueur.potionsMort == 0 && joueur.roleActif == Role.SORCIERE) {
                        joueur.potionsVie = gestionnaireSorciere.potionsVie
                        joueur.potionsMort = gestionnaireSorciere.potionsMort
                    }
                }
                Role.VOYANTE -> {
                    if (joueur.visionsRestantes == 0 && joueur.roleActif == Role.VOYANTE) {
                        joueur.visionsRestantes = gestionnaireVoyante.visionsRestantes
                    }
                }
                else -> Unit
            }
        }
        auditerEtat()
    }

    // =========================================================================
    // TRAITEMENT ATOMIQUE DES MORTS & RÉVÉLATION DE LA CARTE D'ORIGINE
    // =========================================================================

    /**
     * Déclare la mort simultanée d'un groupe de joueurs et révèle publiquement
     * leur rôle d'origine (roleInitial).
     */
    fun declarerMorts(joueurIds: Collection<String>): List<String> {
        if (isGameOver) return emptyList()

        val victimes = joueurs.filter { it.id in joueurIds && it.estEnVie }
        if (victimes.isEmpty()) return emptyList()

        victimes.forEach { victime ->
            victime.estEnVie = false
            victime.carteEstRevelee = true
            victime.estReduitAuSilence = false // Un mort n'a plus besoin d'être sous silence

            // Révélation publique immédiate de la carte avec son RÔLE INITIAL (d'origine)
            onCarteReveleeListener?.invoke(
                RevelationCarteEvent(
                    joueurId = victime.id,
                    joueurNom = victime.nom,
                    roleRevele = victime.roleInitial, // Carte physique d'origine
                    camp = victime.camp
                )
            )
        }

        auditerEtat()
        return victimes.map { it.id }
    }

    fun declarerMort(joueurId: String): Boolean {
        return declarerMorts(listOf(joueurId)).isNotEmpty()
    }

    // =========================================================================
    // ACTIONS PROTÉGÉES & DÉCHÉANCE VERS roleActif
    // =========================================================================

    /**
     * Exécute le sondage d'identité par la Voyante, découvre le roleInitial de la cible,
     * et rétrograde roleActif en VILLAGEOIS_SIMPLE dès épuisement des visions.
     */
    fun executerSondageVoyante(voyanteId: String, cibleId: String): Role? {
        if (isGameOver || voyanteId == cibleId) return null
        val voyante = joueurs.find { it.id == voyanteId && it.estEnVie && it.roleActif == Role.VOYANTE } ?: return null
        val cible = joueurs.find { it.id == cibleId && it.estEnVie } ?: return null

        if (gestionnaireVoyante.consommerVision()) {
            voyante.visionsRestantes = gestionnaireVoyante.visionsRestantes

            // Masquage absolu du Loup Blanc aux yeux de la Voyante
            val roleRevele = when (cible.roleInitial) {
                Role.LOUP_BLANC -> Role.VILLAGEOIS_SIMPLE // La voyante est leurrée
                else -> cible.roleInitial
            }

            // Gestion de la déchéance immédiate si quota épuisé
            if (voyante.visionsRestantes == 0) {
                voyante.roleActif = Role.VILLAGEOIS_SIMPLE
                onRoleDowngradedListener?.invoke(voyante, Role.VILLAGEOIS_SIMPLE)
            }

            auditerEtat()
            return roleRevele
        }
        return null
    }

    /**
     * Utilise une potion de vie sur une cible morte (la ressuscitant et cachant sa carte).
     */
    fun executerSauvetageSorciere(sorciereId: String, cibleId: String): Boolean {
        if (isGameOver) return false
        val sorciere = joueurs.find { it.id == sorciereId && it.estEnVie && it.roleActif == Role.SORCIERE } ?: return false
        val cible = joueurs.find { it.id == cibleId && !it.estEnVie } ?: return false

        if (gestionnaireSorciere.utiliserPotionVie(cible)) {
            sorciere.potionsVie = gestionnaireSorciere.potionsVie
            // Si la victime avait sa carte révélée, elle est réanimée
            cible.carteEstRevelee = false
            verifierDecheanceSorciere(sorciere)
            auditerEtat()
            return true
        }
        return false
    }

    /**
     * Utilise une potion de mort sur une cible vivante (provoquant son décès et sa révélation).
     */
    fun executerPoisonSorciere(sorciereId: String, cibleId: String): Boolean {
        if (isGameOver) return false
        val sorciere = joueurs.find { it.id == sorciereId && it.estEnVie && it.roleActif == Role.SORCIERE } ?: return false
        val cible = joueurs.find { it.id == cibleId && it.estEnVie } ?: return false

        if (gestionnaireSorciere.peutEmpoisonner) {
            gestionnaireSorciere.utiliserPotionMort(cible)
            sorciere.potionsMort = gestionnaireSorciere.potionsMort
            verifierDecheanceSorciere(sorciere)
            // Élimination formelle avec révélation
            declarerMort(cible.id)
            return true
        }
        return false
    }

    private fun verifierDecheanceSorciere(sorciere: Joueur) {
        if (!gestionnaireSorciere.aEncoreDesPotions) {
            sorciere.roleActif = Role.VILLAGEOIS_SIMPLE
            onRoleDowngradedListener?.invoke(sorciere, Role.VILLAGEOIS_SIMPLE)
        }
    }

    /**
     * Audite l'état mathématique de la partie et notifie le superviseur de tout dénouement.
     */
    fun auditerEtat() {
        // Déchéance autoritaire et irréversible si épuisement des ressources
        joueurs.forEach { joueur ->
            if (joueur.roleActif == Role.VOYANTE && joueur.visionsRestantes <= 0) {
                joueur.roleActif = Role.VILLAGEOIS_SIMPLE
                onRoleDowngradedListener?.invoke(joueur, Role.VILLAGEOIS_SIMPLE)
            }
            if (joueur.roleActif == Role.SORCIERE && joueur.potionsVie <= 0 && joueur.potionsMort <= 0) {
                joueur.roleActif = Role.VILLAGEOIS_SIMPLE
                onRoleDowngradedListener?.invoke(joueur, Role.VILLAGEOIS_SIMPLE)
            }
        }

        val nouvelEtat = arbitre.evaluerEtatJeu()
        if (nouvelEtat != issueActuelle) {
            issueActuelle = nouvelEtat
            onStateChangedListener?.invoke(issueActuelle)
        }
    }

    fun reinitialiserSilences() {
        joueurs.forEach { it.estReduitAuSilence = false }
    }

    fun evaluer(): IssuePartie {
        auditerEtat()
        return issueActuelle
    }
}
