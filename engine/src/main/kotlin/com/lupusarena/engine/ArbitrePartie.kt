package com.lupusarena.engine

/**
 * Arbitre officiel évaluant la fin de partie et les conditions de victoire
 * selon la table de vérité stricte de Lupus Arena.
 * L'arbitre inspecte le camp d'origine (camp) et vérifie le pouvoir offensif actif
 * (roleActif == Role.SORCIERE avec poison restant).
 */
class ArbitrePartie(
    val joueurs: MutableList<Joueur> = mutableListOf(),
    val gestionnaireSorciere: GestionnaireSorciere? = null
) {
    /**
     * Constructeur acceptant une List pour compatibilité.
     */
    constructor(joueurs: List<Joueur>, gestionnaireSorciere: GestionnaireSorciere? = null) :
            this(joueurs.toMutableList(), gestionnaireSorciere)

    var issueActuelle: IssuePartie = IssuePartie.EN_COURS
        private set

    fun ajouterJoueur(joueur: Joueur) {
        joueurs.add(joueur)
    }

    fun evaluerEtatJeu(): IssuePartie {
        val vivants = joueurs.filter { it.estEnVie }
        val nbLoups = vivants.count { it.camp == Camp.LOUPS }
        val nbVillageois = vivants.count { it.camp == Camp.VILLAGE }

        // 1. Élimination totale simultanée
        if (nbLoups == 0 && nbVillageois == 0) {
            issueActuelle = IssuePartie.EGALITE
            return issueActuelle
        }

        // 2. Victoire du Village
        if (nbLoups == 0) {
            issueActuelle = IssuePartie.VICTOIRE_VILLAGE
            return issueActuelle
        }

        // 3. Victoire des Loups par annihilation
        if (nbVillageois == 0) {
            issueActuelle = IssuePartie.VICTOIRE_LOUPS
            return issueActuelle
        }

        // 4. Parité / Domination (nbLoups >= nbVillageois)
        if (nbLoups >= nbVillageois) {
            // Configuration 3 joueurs : 2 Loups vs 1 Villageois -> Victoire Loups directe
            if (nbLoups == 2 && nbVillageois == 1) {
                issueActuelle = IssuePartie.VICTOIRE_LOUPS
                return issueActuelle
            }

            // Configuration 2 joueurs (1v1) : 1 Loup vs 1 Villageois
            if (nbLoups == 1 && nbVillageois == 1) {
                val dernierVillageois = vivants.first { it.camp == Camp.VILLAGE }

                // Exception : Sorcière active possédant encore du poison
                val sorciereArmee = dernierVillageois.roleActif == Role.SORCIERE &&
                        (dernierVillageois.potionsMort > 0 || gestionnaireSorciere?.peutEmpoisonner == true)

                if (sorciereArmee) {
                    issueActuelle = IssuePartie.EN_COURS
                    return issueActuelle
                }

                issueActuelle = IssuePartie.VICTOIRE_LOUPS
                return issueActuelle
            }

            // Parité multiple (ex: 2v2, 5v5)
            issueActuelle = IssuePartie.VICTOIRE_LOUPS
            return issueActuelle
        }

        issueActuelle = IssuePartie.EN_COURS
        return issueActuelle
    }

    fun verifierFinDePartie(): IssuePartie = evaluerEtatJeu()
}
