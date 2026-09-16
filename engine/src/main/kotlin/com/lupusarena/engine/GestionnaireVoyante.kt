package com.lupusarena.engine

/**
 * Gestionnaire du rôle de la Voyante :
 * - À 4 joueurs -> 1 vision
 * - De 5 à 9 joueurs -> 2 visions
 * - De 10 à 14 joueurs -> 3 visions
 * - 15+ joueurs -> totalJoueurs / 4
 * - Décrémentation à chaque inspection nocturne
 * - Révocation automatique vers Role.VILLAGEOIS_SIMPLE dès que visionsRestantes == 0
 * - IMPORTANT : Seul roleActif est déchu, roleInitial reste Role.VOYANTE
 */
class GestionnaireVoyante(
    val totalJoueurs: Int,
    val joueur: Joueur? = null
) {
    /**
     * Constructeur secondaire facilitant l'instanciation directe avec un Joueur et le total de joueurs.
     */
    constructor(joueur: Joueur, totalJoueurs: Int) : this(totalJoueurs, joueur)

    val maxVisions: Int = when {
        totalJoueurs <= 4 -> 1
        totalJoueurs < 10 -> 2
        totalJoueurs < 15 -> 3
        else -> totalJoueurs / 4
    }

    var visionsRestantes: Int = maxVisions
        private set

    init {
        joueur?.let {
            require(it.roleInitial == Role.VOYANTE) {
                "Le joueur doit avoir pour rôle initial Role.VOYANTE."
            }
            it.visionsRestantes = maxVisions
        }
    }

    val peutSonder: Boolean
        get() = visionsRestantes > 0

    val aEncoreDesVisions: Boolean
        get() = peutSonder

    fun consommerVision(): Boolean {
        if (peutSonder) {
            visionsRestantes--
            joueur?.visionsRestantes = visionsRestantes
            verifierEtAppliquerDecheance()
            return true
        }
        return false
    }

    /**
     * Inspecte l'identité secrète d'un joueur vivant.
     * Le Loup Blanc apparaît sous l'apparence trompeuse d'un Simple Villageois.
     */
    fun inspecter(cible: Joueur): Role? {
        if (joueur != null && (!joueur.estEnVie || joueur.roleActif != Role.VOYANTE)) {
            return null
        }
        if (consommerVision()) {
            return when (cible.roleInitial) {
                Role.LOUP_BLANC -> Role.VILLAGEOIS_SIMPLE
                else -> cible.roleInitial
            }
        }
        return null
    }

    /**
     * Dès que visionsRestantes == 0, roleActif est immédiatement transformé en VILLAGEOIS_SIMPLE.
     * roleInitial reste Role.VOYANTE.
     */
    fun verifierEtAppliquerDecheance(): Boolean {
        joueur?.let {
            if (visionsRestantes == 0 && it.roleActif == Role.VOYANTE) {
                it.roleActif = Role.VILLAGEOIS_SIMPLE
                return true
            }
        }
        return false
    }
}
