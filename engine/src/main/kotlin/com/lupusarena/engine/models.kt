package com.lupusarena.engine

/**
 * Camp d'appartenance pour chaque rôle du jeu.
 */
enum class Camp {
    VILLAGE,
    LOUPS
}

/**
 * Rôles gérés dans le moteur de jeu.
 */
enum class Role(val nomAffiche: String, val campParDefaut: Camp = Camp.VILLAGE) {
    LOUP_GAROU("Loup-Garou", Camp.LOUPS),
    LOUP_BLANC("Loup Blanc", Camp.LOUPS),
    VILLAGEOIS_SIMPLE("Simple Villageois", Camp.VILLAGE),
    SORCIERE("Sorcière", Camp.VILLAGE),
    VOYANTE("Voyante", Camp.VILLAGE),
    CAPITAINE("Capitaine", Camp.VILLAGE);

    val estLoup: Boolean get() = this == LOUP_GAROU || this == LOUP_BLANC
    val estVillageois: Boolean get() = !estLoup
}

/**
 * États d'arbitrage et dénouement d'une partie.
 */
enum class IssuePartie {
    EN_COURS,
    VICTOIRE_VILLAGE,
    VICTOIRE_LOUPS,
    EGALITE
}

/**
 * Modèle de données représentant un joueur dans la partie.
 * Distingue explicitement le rôle d'origine (carte physique distribuée)
 * et le rôle dynamique actif (sujet à déchéance en cours de partie).
 */
data class Joueur(
    val id: String,
    val nom: String,
    val roleInitial: Role,                        // Rôle d'origine (carte physique distribuée)
    var roleActif: Role = roleInitial,           // Rôle fonctionnel (bascule en VILLAGEOIS_SIMPLE si déchu)
    var estEnVie: Boolean = true,
    var carteEstRevelee: Boolean = false,        // Passe à true à la mort
    var estReduitAuSilence: Boolean = false,     // Pouvoir de mutisme pour le jour suivant
    var potionsVie: Int = 0,
    var potionsMort: Int = 0,
    var visionsRestantes: Int = 0,
    var estCapitaine: Boolean = false,           // Titre de Capitaine / Maire du village
    var causeMort: CauseMort? = null             // Cause de décès
) {
    /**
     * Constructeur secondaire pour compatibilité avec l'ancienne signature (id, nom, role).
     */
    constructor(
        id: String,
        nom: String,
        role: Role,
        estEnVie: Boolean = true,
        estReduitAuSilence: Boolean = false,
        potionsVie: Int = 0,
        potionsMort: Int = 0,
        visionsRestantes: Int = 0,
        estCapitaine: Boolean = false,
        causeMort: CauseMort? = null
    ) : this(
        id = id,
        nom = nom,
        roleInitial = role,
        roleActif = role,
        estEnVie = estEnVie,
        carteEstRevelee = !estEnVie,
        estReduitAuSilence = estReduitAuSilence,
        potionsVie = potionsVie,
        potionsMort = potionsMort,
        visionsRestantes = visionsRestantes,
        estCapitaine = estCapitaine,
        causeMort = causeMort
    )

    /**
     * Propriété d'accès et de modification du rôle courant pour rétro-compatibilité.
     */
    var role: Role
        get() = roleActif
        set(value) {
            roleActif = value
        }

    /**
     * Le camp est STRICTEMENT indexé sur la carte d'origine (roleInitial).
     */
    val camp: Camp
        get() = if (roleInitial.estLoup) Camp.LOUPS else Camp.VILLAGE

    val estLoupEnVie: Boolean get() = estEnVie && camp == Camp.LOUPS
    val estVillageoisEnVie: Boolean get() = estEnVie && camp == Camp.VILLAGE
}

/**
 * Détermine le libellé textuel du rôle visible par un spectateur donné.
 * - 1. Si la carte est révélée publiquement (mort) -> roleInitial.nomAffiche
 * - 2. Un joueur voit toujours son propre rôle actif
 * - 3. Les Loups se reconnaissent entre eux -> roleInitial.nomAffiche ("Loup-Garou" ou "Loup Blanc"), JAMAIS "Simple Villageois"
 * - 4. Pour un simple villageois qui regarde un inconnu vivant -> "Inconnu"
 */
fun Joueur.determinerRoleVisiblePar(spectateur: Joueur): String {
    // 1. Si la carte est révélée publiquement (mort)
    if (this.carteEstRevelee) {
        return this.roleInitial.nomAffiche
    }

    // 2. Un joueur voit toujours son propre rôle
    if (this.id == spectateur.id) {
        return this.roleActif.nomAffiche
    }

    // 3. Les Loups se reconnaissent entre eux
    if (spectateur.roleInitial.estLoup && this.roleInitial.estLoup) {
        return this.roleInitial.nomAffiche // Affiche "Loup-Garou" ou "Loup Blanc", JAMAIS "Simple Villageois"
    }

    // 4. Pour un simple villageois qui regarde un inconnu vivant : rôle masqué
    return "Inconnu"
}

/**
 * Événement émis lors de la mort d'un joueur pour la révélation publique
 * de sa carte d'origine à l'ensemble du village.
 */
data class RevelationCarteEvent(
    val joueurId: String,
    val joueurNom: String,
    val roleRevele: Role, // STRICTEMENT égal à roleInitial
    val camp: Camp
)

/**
 * Événement émis à l'aube pour réduire un joueur au silence (vocal et textuel).
 */
data class JoueurSilenceEvent(
    val joueurId: String,
    val joueurNom: String,
    val tourNumero: Int
)

/**
 * Cause d'élimination physique d'un joueur.
 */
enum class CauseMort {
    MORSURE_LOUPS,
    POISON_SORCIERE,
    VOTE_VILLAGE
}

/**
 * Payload d'événement instantané émis dès la mort d'un joueur,
 * pour diffusion immédiate par socket / Firebase avant même l'arbitrage.
 */
data class MortInstantaneeEvent(
    val joueurId: String,
    val joueurNom: String,
    val roleAffiche: Role, // roleInitial obligatoire
    val camp: Camp,
    val causeMort: CauseMort,
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Événement de passation de l'écharpe de Capitaine (choix direct ou d'office).
 */
data class CapitaineSuccessionEvent(
    val ancienCapitaineId: String,
    val ancienCapitaineNom: String,
    val nouveauCapitaineId: String,
    val nouveauCapitaineNom: String,
    val estPassationAutomatique: Boolean = false,
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Fiche individuelle d'un joueur pour le tableau récapitulatif final.
 */
data class BilanJoueur(
    val id: String,
    val nom: String,
    val roleInitial: Role,
    val roleActif: Role,
    val camp: Camp,
    val estEnVie: Boolean,
    val estCapitaine: Boolean,
    val causeMort: CauseMort? = null
)

/**
 * Bilan complet émis lors de la fin de partie (PhaseJeu.TERMINEE).
 */
data class BilanPartie(
    val issue: IssuePartie,
    val nbTours: Int,
    val vainqueurCamp: Camp?,
    val joueurs: List<BilanJoueur>,
    val totalVivants: Int = joueurs.count { it.estEnVie },
    val totalMorts: Int = joueurs.count { !it.estEnVie },
    val survivantsVillage: Int = joueurs.count { it.estEnVie && it.camp == Camp.VILLAGE },
    val survivantsLoups: Int = joueurs.count { it.estEnVie && it.camp == Camp.LOUPS }
)
