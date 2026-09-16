package com.lupusarena.engine

/**
 * Gestionnaire du rôle de la Sorcière :
 * - Calcul initial du quota de potions : maxPotions = maxOf(1, totalJoueurs / 10) (division entière)
 *   * Moins de 20 joueurs (ex: 4 à 19) -> 1 potion de vie et 1 potion de mort
 *   * De 20 à 29 joueurs (ex: 20 à 29) -> 2 potions de chaque
 *   * 30 joueurs et plus (ex: 30+)     -> 3+ potions de chaque
 * - Stocks indépendants pour potionsVie et potionsMort
 * - Application des effets en cours de partie
 * - Révocation automatique du pouvoir vers Role.VILLAGEOIS_SIMPLE dès épuisement total (potionsVie == 0 && potionsMort == 0)
 */
class GestionnaireSorciere(
    val totalJoueurs: Int,
    val joueur: Joueur? = null
) {
    /**
     * Constructeur secondaire facilitant l'instanciation directe avec un Joueur et le total de joueurs.
     */
    constructor(joueur: Joueur, totalJoueurs: Int) : this(totalJoueurs, joueur)

    val maxPotions: Int = maxOf(1, totalJoueurs / 10)

    var potionsVie: Int = maxPotions
        private set

    var potionsMort: Int = maxPotions
        private set

    init {
        joueur?.let {
            require(it.role == Role.SORCIERE) {
                "Le joueur doit être assigné au rôle Role.SORCIERE."
            }
            it.potionsVie = maxPotions
            it.potionsMort = maxPotions
        }
    }

    val aEncoreDesPotions: Boolean get() = potionsVie > 0 || potionsMort > 0
    val peutSauver: Boolean get() = potionsVie > 0
    val peutEmpoisonner: Boolean get() = potionsMort > 0

    /**
     * Utilise une potion de vie sur la victime désignée de la nuit pour annuler sa mort.
     * @param victime Le joueur ciblé par les loups.
     * @return true si la potion a pu être consommée, false sinon.
     */
    fun utiliserPotionVie(victime: Joueur): Boolean {
        if (joueur != null && (!joueur.estEnVie || joueur.role != Role.SORCIERE)) {
            return false
        }
        if (potionsVie <= 0) {
            return false
        }
        potionsVie--
        joueur?.potionsVie = potionsVie
        victime.estEnVie = true
        verifierEtAppliquerDecheance()
        return true
    }

    /**
     * Utilise une potion de mort pour éliminer un joueur vivant.
     * @param cible Le joueur vivant ciblé par la sorcière.
     * @return true si la potion a pu être consommée, false sinon.
     */
    fun utiliserPotionMort(cible: Joueur): Boolean {
        if (joueur != null && (!joueur.estEnVie || joueur.role != Role.SORCIERE)) {
            return false
        }
        if (potionsMort <= 0 || !cible.estEnVie) {
            return false
        }
        potionsMort--
        joueur?.potionsMort = potionsMort
        cible.estEnVie = false
        verifierEtAppliquerDecheance()
        return true
    }

    /**
     * Vérifie si les deux stocks de potions sont à zéro.
     * Si oui, le rôle actif est immédiatement révoqué en Role.VILLAGEOIS_SIMPLE.
     */
    fun verifierEtAppliquerDecheance(): Boolean {
        joueur?.let {
            if (potionsVie == 0 && potionsMort == 0 && it.role == Role.SORCIERE) {
                it.role = Role.VILLAGEOIS_SIMPLE
                return true
            }
        }
        return false
    }
}
