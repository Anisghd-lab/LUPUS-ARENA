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
enum class Role(val camp: Camp) {
    VILLAGEOIS_SIMPLE(Camp.VILLAGE),
    VOYANTE(Camp.VILLAGE),
    SORCIERE(Camp.VILLAGE),
    LOUP_GAROU(Camp.LOUPS);

    val estLoup: Boolean get() = this.camp == Camp.LOUPS
    val estVillageois: Boolean get() = this.camp == Camp.VILLAGE
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
 */
data class Joueur(
    val id: String,
    val nom: String,
    var role: Role,
    var estEnVie: Boolean = true,
    var potionsVie: Int = 0,
    var potionsMort: Int = 0,
    var visionsRestantes: Int = 0
) {
    val camp: Camp get() = role.camp
    val estLoupEnVie: Boolean get() = estEnVie && role.estLoup
    val estVillageoisEnVie: Boolean get() = estEnVie && role.estVillageois
}
