package com.lupusarena.engine

/**
 * Gestionnaire du rôle de la Sorcière :
 * - Calcul initial du quota de potions : maxPotions = maxOf(1, totalJoueurs / 10) (division entière)
 *   * Moins de 20 joueurs -> 1 potion de vie et 1 potion de mort
 *   * De 20 à 29 joueurs  -> 2 potions de chaque
 *   * 30 joueurs et plus  -> 3+ potions de chaque
 * - Stocks indépendants pour potionsVie et potionsMort
 * - Révocation automatique vers Role.VILLAGEOIS_SIMPLE dès épuisement total (potionsVie == 0 && potionsMort == 0)
 * - IMPORTANT : Seul roleActif est déchu, roleInitial reste Role.SORCIERE
 */
class GestionnaireSorciere(
    val totalJoueurs: Int,
    val joueur: Joueur? = null
) {
    /**
     * Constructeur secondaire facilitant l'instanciation directe avec un Joueur et le total de joueurs.
     */
    constructor(joueur: Joueur, totalJoueurs: Int) : this(totalJoueurs, joueur)

    val maxPotionsInitiale: Int = maxOf(1, totalJoueurs / 10)
    val maxPotions: Int get() = maxPotionsInitiale

    var potionsVie: Int = maxPotionsInitiale
        private set

    var potionsMort: Int = maxPotionsInitiale
        private set

    init {
        joueur?.let {
            require(it.roleInitial == Role.SORCIERE) {
                "Le joueur doit avoir pour rôle initial Role.SORCIERE."
            }
            it.potionsVie = maxPotionsInitiale
            it.potionsMort = maxPotionsInitiale
        }
    }

    val aEncoreDesPotions: Boolean
        get() = potionsVie > 0 || potionsMort > 0

    val peutSauver: Boolean
        get() = potionsVie > 0

    val peutEmpoisonner: Boolean
        get() = potionsMort > 0

    fun consommerPotionVie(): Boolean {
        if (peutSauver) {
            potionsVie--
            joueur?.potionsVie = potionsVie
            verifierEtAppliquerDecheance()
            return true
        }
        return false
    }

    fun consommerPotionMort(): Boolean {
        if (peutEmpoisonner) {
            potionsMort--
            joueur?.potionsMort = potionsMort
            verifierEtAppliquerDecheance()
            return true
        }
        return false
    }

    /**
     * Utilise une potion de vie sur une cible (victime des loups).
     */
    fun utiliserPotionVie(cible: Joueur): Boolean {
        if (peutSauver && !cible.estEnVie) {
            cible.estEnVie = true
            consommerPotionVie()
            return true
        }
        return false
    }

    /**
     * Utilise une potion de mort pour éliminer une cible vivante.
     */
    fun utiliserPotionMort(cible: Joueur): Boolean {
        if (peutEmpoisonner && cible.estEnVie) {
            cible.estEnVie = false
            consommerPotionMort()
            return true
        }
        return false
    }

    /**
     * Dès que les deux potions sont épuisées, le rôle actif est rétrogradé en VILLAGEOIS_SIMPLE.
     * roleInitial reste Role.SORCIERE.
     */
    fun verifierEtAppliquerDecheance(): Boolean {
        joueur?.let {
            if (potionsVie == 0 && potionsMort == 0 && it.roleActif == Role.SORCIERE) {
                it.roleActif = Role.VILLAGEOIS_SIMPLE
                return true
            }
        }
        return false
    }
}
