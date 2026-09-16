package com.lupusarena.engine

/**
 * Gestionnaire du rôle de la Voyante :
 * - À 4 joueurs -> 1 vision
 * - De 5 à 9 joueurs -> 2 visions
 * - De 10 à 14 joueurs -> 3 visions
 * - 15+ joueurs -> N / 4
 * - Décrémentation à chaque inspection nocturne via consommerVision()
 * - Révocation automatique et immédiate du rôle en Role.VILLAGEOIS_SIMPLE dès que visionsRestantes == 0
 */
class GestionnaireVoyante(
    val totalJoueurs: Int,
    val joueur: Joueur? = null
) {
    /**
     * Constructeur secondaire avec joueur en premier argument pour interopérabilité.
     */
    constructor(joueur: Joueur, totalJoueurs: Int) : this(totalJoueurs, joueur)

    // À 4 joueurs -> 1 vision
    // De 5 à 9 joueurs -> 2 visions
    // De 10 à 14 joueurs -> 3 visions
    // 15+ joueurs -> N / 4
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
            require(it.role == Role.VOYANTE) {
                "Le joueur doit être assigné au rôle Role.VOYANTE."
            }
            it.visionsRestantes = maxVisions
        }
    }

    fun peutSonder(): Boolean = visionsRestantes > 0

    fun consommerVision(): Boolean {
        if (peutSonder()) {
            visionsRestantes--
            joueur?.let {
                it.visionsRestantes = visionsRestantes
                verifierEtAppliquerDecheance()
            }
            return true
        }
        return false
    }

    val aEncoreDesVisions: Boolean get() = peutSonder()

    /**
     * Inspecte l'identité secrète d'un joueur vivant.
     * Consomme 1 vision et déclenche la déchéance si le quota tombe à 0.
     * @param cible Le joueur ciblé pour la révélation.
     * @return Le rôle découvert, ou null si l'inspection est impossible.
     */
    fun inspecter(cible: Joueur): Role? {
        if (joueur != null && (!joueur.estEnVie || joueur.role != Role.VOYANTE)) {
            return null
        }
        if (!consommerVision()) {
            return null
        }
        return cible.role
    }

    /**
     * Dès que visionsRestantes == 0, le rôle actif est immédiatement transformé en Role.VILLAGEOIS_SIMPLE.
     */
    fun verifierEtAppliquerDecheance(): Boolean {
        joueur?.let {
            if (visionsRestantes == 0 && it.role == Role.VOYANTE) {
                it.role = Role.VILLAGEOIS_SIMPLE
                return true
            }
        }
        return false
    }
}
