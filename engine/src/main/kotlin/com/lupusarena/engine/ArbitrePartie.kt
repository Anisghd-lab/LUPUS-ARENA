package com.lupusarena.engine

/**
 * Arbitre officiel évaluant la fin de partie et les conditions de victoire
 * selon la table de vérité stricte de Lupus Arena (N <= 3 et parité étendue) :
 *
 * | Vivants restants | Composition            | Rôle Villageois                                | Issue            | Explication |
 * |------------------|------------------------|------------------------------------------------|------------------|-------------|
 * | 3 joueurs        | 2 Loups, 1 Villageois  | N'importe lequel                               | VICTOIRE_LOUPS   | Même face à une sorcière armée : elle ne peut tuer qu'1 loup, l'autre loup la dévore la nuit. Majorité absolue aux loups. |
 * | 3 joueurs        | 1 Loup, 2 Villageois   | N'importe lesquels                             | EN_COURS         | Le village a la majorité au vote pour tenter d'éliminer le loup. |
 * | 2 joueurs        | 1 Loup, 1 Villageois   | SORCIERE avec poison                           | EN_COURS         | Duel létal la nuit (elle peut empoisonner le dernier loup). |
 * | 2 joueurs        | 1 Loup, 1 Villageois   | VILLAGEOIS_SIMPLE (ou Sorcière/Voyante déchue) | VICTOIRE_LOUPS   | Pas de pouvoir d'élimination, le loup gagne au tour suivant. |
 * | 2 joueurs        | 2 Loups, 0 Villageois  | —                                              | VICTOIRE_LOUPS   | Tous les villageois sont morts. |
 * | 2 joueurs        | 0 Loup, 2 Villageois   | —                                              | VICTOIRE_VILLAGE | Tous les loups sont morts. |
 * | 1 joueur         | 1 Loup                 | —                                              | VICTOIRE_LOUPS   | Seul survivant. |
 * | 1 joueur         | 1 Villageois           | —                                              | VICTOIRE_VILLAGE | Seul survivant. |
 * | 0 joueur         | Personne               | —                                              | EGALITE          | Double mort simultanée. |
 */
class ArbitrePartie(
    val joueurs: MutableList<Joueur> = mutableListOf()
) {
    var issueActuelle: IssuePartie = IssuePartie.EN_COURS
        private set

    /**
     * Ajoute un joueur à la partie.
     */
    fun ajouterJoueur(joueur: Joueur) {
        joueurs.add(joueur)
    }

    /**
     * Méthode d'évaluation optimisée pour les règles de fin de partie.
     * Met à jour [issueActuelle] et renvoie l'issue constatée.
     */
    fun evaluerEtatJeu(): IssuePartie {
        val vivants = joueurs.filter { it.estEnVie }
        val nbLoups = vivants.count { it.camp == Camp.LOUPS }
        val nbVillageois = vivants.count { it.camp == Camp.VILLAGE }

        // 1. Victoires absolues et égalité
        if (nbLoups == 0 && nbVillageois == 0) {
            issueActuelle = IssuePartie.EGALITE
            return issueActuelle
        }
        if (nbLoups == 0) {
            issueActuelle = IssuePartie.VICTOIRE_VILLAGE
            return issueActuelle
        }
        if (nbVillageois == 0) {
            issueActuelle = IssuePartie.VICTOIRE_LOUPS
            return issueActuelle
        }

        // 2. Évaluation des phases finales (parité nbLoups >= nbVillageois)
        if (nbLoups >= nbVillageois) {
            // Configuration 3 joueurs : 2 Loups vs 1 Villageois -> Victoire Loups directe
            if (nbLoups == 2 && nbVillageois == 1) {
                issueActuelle = IssuePartie.VICTOIRE_LOUPS
                return issueActuelle
            }

            // Configuration 2 joueurs (1v1) : 1 Loup vs 1 Villageois
            if (nbLoups == 1 && nbVillageois == 1) {
                val dernierVillageois = vivants.first { it.camp == Camp.VILLAGE }

                // Seul cas où le jeu continue : Sorcière avec encore du poison
                val peutEncoreTuer = dernierVillageois.role == Role.SORCIERE && dernierVillageois.potionsMort > 0

                if (peutEncoreTuer) {
                    issueActuelle = IssuePartie.EN_COURS
                    return issueActuelle
                }

                // Simple villageois ou rôle déchu -> Victoire des loups
                issueActuelle = IssuePartie.VICTOIRE_LOUPS
                return issueActuelle
            }

            issueActuelle = IssuePartie.VICTOIRE_LOUPS
            return issueActuelle
        }

        // Si villageois > loups (ex: 1 loup vs 2 villageois à 3 joueurs)
        issueActuelle = IssuePartie.EN_COURS
        return issueActuelle
    }

    /**
     * Alias conservé pour rétro-compatibilité avec les appels existants.
     */
    fun verifierFinDePartie(): IssuePartie = evaluerEtatJeu()
}
