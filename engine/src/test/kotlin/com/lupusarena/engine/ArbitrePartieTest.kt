package com.lupusarena.engine

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class ArbitrePartieTest {

    private lateinit var arbitre: ArbitrePartie

    @BeforeEach
    fun setUp() {
        arbitre = ArbitrePartie()
    }

    // =========================================================================
    // 1. TESTS DE DÉCHÉANCE DES POUVOIRS DE LA VOYANTE
    // =========================================================================

    @Test
    @DisplayName("La Voyante se transforme en Simple Villageoise après 3 sondages")
    fun testTransformationVoyanteApresTroisSondages() {
        val voyante = Joueur("v1", "Voyante", Role.VOYANTE)
        val cible1 = Joueur("j1", "Joueur 1", Role.VILLAGEOIS_SIMPLE)
        val cible2 = Joueur("j2", "Joueur 2", Role.LOUP_GAROU)
        val cible3 = Joueur("j3", "Joueur 3", Role.SORCIERE)

        val gestionnaire = GestionnaireVoyante(voyante, totalJoueurs = 12)
        assertEquals(3, gestionnaire.visionsRestantes)
        assertEquals(Role.VOYANTE, voyante.role)

        // Nuit 1
        val r1 = gestionnaire.inspecter(cible1)
        assertEquals(Role.VILLAGEOIS_SIMPLE, r1)
        assertEquals(2, gestionnaire.visionsRestantes)
        assertEquals(Role.VOYANTE, voyante.role)

        // Nuit 2
        val r2 = gestionnaire.inspecter(cible2)
        assertEquals(Role.LOUP_GAROU, r2)
        assertEquals(1, gestionnaire.visionsRestantes)
        assertEquals(Role.VOYANTE, voyante.role)

        // Nuit 3 : Dernière vision disponible
        val r3 = gestionnaire.inspecter(cible3)
        assertEquals(Role.SORCIERE, r3)
        assertEquals(0, gestionnaire.visionsRestantes)

        // DÉCHÉANCE IMMÉDIATE
        assertEquals(Role.VILLAGEOIS_SIMPLE, voyante.role, "La Voyante doit devenir un Simple Villageois dès l'épuisement de son quota.")

        // Toute tentative ultérieure d'inspection doit échouer
        val r4 = gestionnaire.inspecter(cible1)
        assertNull(r4)
    }

    @Test
    @DisplayName("Calcul dynamique des visions de la Voyante selon les paliers de joueurs")
    fun testCalculDynamiqueVisionsSelonTaillePartie() {
        // À 4 joueurs -> 1 vision
        assertEquals(1, GestionnaireVoyante(4).maxVisions)

        // De 5 à 9 joueurs -> 2 visions
        assertEquals(2, GestionnaireVoyante(5).maxVisions)
        assertEquals(2, GestionnaireVoyante(6).maxVisions)
        assertEquals(2, GestionnaireVoyante(8).maxVisions)
        assertEquals(2, GestionnaireVoyante(9).maxVisions)

        // De 10 à 14 joueurs -> 3 visions
        assertEquals(3, GestionnaireVoyante(10).maxVisions)
        assertEquals(3, GestionnaireVoyante(12).maxVisions)
        assertEquals(3, GestionnaireVoyante(14).maxVisions)

        // 15+ joueurs -> totalJoueurs / 4
        assertEquals(3, GestionnaireVoyante(15).maxVisions) // 15 / 4 = 3
        assertEquals(4, GestionnaireVoyante(16).maxVisions) // 16 / 4 = 4
        assertEquals(4, GestionnaireVoyante(19).maxVisions) // 19 / 4 = 4
        assertEquals(5, GestionnaireVoyante(20).maxVisions) // 20 / 4 = 5
        assertEquals(6, GestionnaireVoyante(24).maxVisions) // 24 / 4 = 6
    }

    @Test
    @DisplayName("Test des méthodes peutSonder() et consommerVision()")
    fun testPeutSonderEtConsommerVision() {
        val g = GestionnaireVoyante(totalJoueurs = 8) // 2 visions
        assertEquals(2, g.visionsRestantes)
        assertTrue(g.peutSonder())

        assertTrue(g.consommerVision())
        assertEquals(1, g.visionsRestantes)
        assertTrue(g.peutSonder())

        assertTrue(g.consommerVision())
        assertEquals(0, g.visionsRestantes)
        assertFalse(g.peutSonder())

        assertFalse(g.consommerVision(), "Ne peut plus consommer de vision quand le quota est à 0")
        assertEquals(0, g.visionsRestantes)
    }

    // =========================================================================
    // 2. TESTS DE DÉCHÉANCE DES POUVOIRS DE LA SORCIÈRE
    // =========================================================================

    @Test
    @DisplayName("La Sorcière se transforme en Simple Villageoise après utilisation de ses deux potions")
    fun testTransformationSorciereApresUtilisationDeuxPotions() {
        // Pour une partie à 10 joueurs : maxPotions = maxOf(1, 10 / 10) = 1
        val sorciere = Joueur("s1", "Sorcière", Role.SORCIERE)
        val victime = Joueur("v1", "Victime Loups", Role.VILLAGEOIS_SIMPLE, estEnVie = false)
        val suspect = Joueur("l1", "Suspect", Role.LOUP_GAROU, estEnVie = true)

        val gestionnaire = GestionnaireSorciere(sorciere, totalJoueurs = 10)
        assertEquals(1, gestionnaire.potionsVie)
        assertEquals(1, gestionnaire.potionsMort)
        assertEquals(Role.SORCIERE, sorciere.role)

        // 1. Sauvetage de la victime avec la potion de vie
        val sauvetageReussi = gestionnaire.utiliserPotionVie(victime)
        assertTrue(sauvetageReussi)
        assertTrue(victime.estEnVie)
        assertEquals(0, gestionnaire.potionsVie)
        assertEquals(1, gestionnaire.potionsMort)
        assertEquals(Role.SORCIERE, sorciere.role, "La sorcière conserve son rôle tant qu'il lui reste au moins une potion de mort.")

        // 2. Élimination du suspect avec la potion de mort
        val empoisonnementReussi = gestionnaire.utiliserPotionMort(suspect)
        assertTrue(empoisonnementReussi)
        assertFalse(suspect.estEnVie)
        assertEquals(0, gestionnaire.potionsVie)
        assertEquals(0, gestionnaire.potionsMort)

        // DÉCHÉANCE IMMÉDIATE
        assertEquals(Role.VILLAGEOIS_SIMPLE, sorciere.role, "La sorcière doit être rétrogradée en Simple Villageois dès épuisement de ses deux stocks.")
    }

    @Test
    @DisplayName("Calcul dynamique des stocks de potions selon le nombre de joueurs")
    fun testCalculInitialPotionsSelonTaillePartie() {
        // 8 joueurs : maxOf(1, 8/10) = 1
        val s8 = Joueur("s8", "S8", Role.SORCIERE)
        val g8 = GestionnaireSorciere(s8, totalJoueurs = 8)
        assertEquals(1, g8.maxPotions)
        assertEquals(1, g8.potionsVie)
        assertEquals(1, g8.potionsMort)
        assertTrue(g8.peutSauver)
        assertTrue(g8.peutEmpoisonner)

        // 15 joueurs : maxOf(1, 15/10) = 1
        val s15 = Joueur("s15", "S15", Role.SORCIERE)
        val g15 = GestionnaireSorciere(s15, totalJoueurs = 15)
        assertEquals(1, g15.maxPotions)
        assertEquals(1, g15.potionsVie)
        assertEquals(1, g15.potionsMort)

        // 24 joueurs : maxOf(1, 24/10) = 2
        val s24 = Joueur("s24", "S24", Role.SORCIERE)
        val g24 = GestionnaireSorciere(s24, totalJoueurs = 24)
        assertEquals(2, g24.maxPotions)
        assertEquals(2, g24.potionsVie)
        assertEquals(2, g24.potionsMort)

        // Instanciation standalone sans Joueur
        assertEquals(1, GestionnaireSorciere(10).maxPotions)
        assertEquals(2, GestionnaireSorciere(20).maxPotions)
        assertEquals(3, GestionnaireSorciere(35).maxPotions)
    }

    // =========================================================================
    // 3. TESTS DUEL 1v1 LOUP CONTRE SORCIÈRE ARMÉE
    // =========================================================================

    @Test
    @DisplayName("Duel 1v1 : 1 loup contre 1 sorcière armée de potion de mort -> EN_COURS")
    fun testDuel1v1LoupContreSorciereArmee() {
        val loup = Joueur("l1", "Grand Loup", Role.LOUP_GAROU, estEnVie = true)
        val sorciere = Joueur("s1", "Circé", Role.SORCIERE, estEnVie = true, potionsVie = 0, potionsMort = 1)

        arbitre.ajouterJoueur(loup)
        arbitre.ajouterJoueur(sorciere)

        val issue = arbitre.verifierFinDePartie()
        assertEquals(IssuePartie.EN_COURS, issue, "Un duel 1v1 avec une sorcière armée doit rester EN_COURS car l'issue nocturne est létale pour les deux.")
    }

    // =========================================================================
    // 4. TESTS DUEL 1v1 LOUP CONTRE SIMPLE VILLAGEOIS (OU ANCIENNE VOYANTE / SORCIÈRE DÉCHUE)
    // =========================================================================

    @Test
    @DisplayName("Duel 1v1 : 1 loup contre 1 sorcière sans potion de mort (ou devenue villageoise) -> VICTOIRE_LOUPS")
    fun testDuel1v1LoupContreSorciereDechue() {
        val loup = Joueur("l1", "Grand Loup", Role.LOUP_GAROU, estEnVie = true)
        // La sorcière a épuisé ses potions, elle est devenue simple villageoise
        val ancienneSorciere = Joueur("s1", "Circé", Role.VILLAGEOIS_SIMPLE, estEnVie = true, potionsVie = 0, potionsMort = 0)

        arbitre.ajouterJoueur(loup)
        arbitre.ajouterJoueur(ancienneSorciere)

        val issue = arbitre.verifierFinDePartie()
        assertEquals(IssuePartie.VICTOIRE_LOUPS, issue, "Face à un villageois sans pouvoir létal, le loup l'emporte immédiatement par parité.")
    }

    @Test
    @DisplayName("Duel 1v1 : 1 loup contre 1 voyante ayant épuisé ses visions -> VICTOIRE_LOUPS")
    fun testDuel1v1LoupContreVoyanteDechue() {
        val loup = Joueur("l1", "Grand Loup", Role.LOUP_GAROU, estEnVie = true)
        val voyanteDechue = Joueur("v1", "Cassandre", Role.VILLAGEOIS_SIMPLE, estEnVie = true, visionsRestantes = 0)

        arbitre.ajouterJoueur(loup)
        arbitre.ajouterJoueur(voyanteDechue)

        val issue = arbitre.verifierFinDePartie()
        assertEquals(IssuePartie.VICTOIRE_LOUPS, issue, "Le loup dévore le dernier villageois simple, victoire immédiate.")
    }

    @Test
    @DisplayName("Duel 1v1 : 1 loup contre 1 voyante encore active (non déchue) -> VICTOIRE_LOUPS")
    fun testDuel1v1LoupContreVoyanteActive() {
        val loup = Joueur("l1", "Grand Loup", Role.LOUP_GAROU, estEnVie = true)
        val voyanteActive = Joueur("v1", "Cassandre", Role.VOYANTE, estEnVie = true, visionsRestantes = 2)

        arbitre.ajouterJoueur(loup)
        arbitre.ajouterJoueur(voyanteActive)

        val issue = arbitre.verifierFinDePartie()
        assertEquals(IssuePartie.VICTOIRE_LOUPS, issue, "La voyante n'a pas de pouvoir létal : victoire immédiate du loup à parité 1v1.")
    }

    // =========================================================================
    // 5. TESTS CAS DE DOMINATION ET PARITÉS ÉTENDUES (2v1, 2v2, 5v5)
    // =========================================================================

    @Test
    @DisplayName("2 loups contre 1 sorcière armée -> VICTOIRE_LOUPS (la meute domine même face à la mort)")
    fun testDeuxLoupsContreSorciereArmee() {
        val loup1 = Joueur("l1", "Loup 1", Role.LOUP_GAROU, estEnVie = true)
        val loup2 = Joueur("l2", "Loup 2", Role.LOUP_GAROU, estEnVie = true)
        val sorciere = Joueur("s1", "Sorcière", Role.SORCIERE, estEnVie = true, potionsMort = 1)

        arbitre.ajouterJoueur(loup1)
        arbitre.ajouterJoueur(loup2)
        arbitre.ajouterJoueur(sorciere)

        val issue = arbitre.verifierFinDePartie()
        assertEquals(IssuePartie.VICTOIRE_LOUPS, issue, "Même avec une potion de mort, la sorcière ne peut tuer qu'un seul loup. La meute gagne immédiatement.")
    }

    @Test
    @DisplayName("Parité 2 loups contre 2 villageois -> VICTOIRE_LOUPS")
    fun testPariteDeuxContreDeux() {
        arbitre.ajouterJoueur(Joueur("l1", "L1", Role.LOUP_GAROU))
        arbitre.ajouterJoueur(Joueur("l2", "L2", Role.LOUP_GAROU))
        arbitre.ajouterJoueur(Joueur("v1", "V1", Role.VILLAGEOIS_SIMPLE))
        arbitre.ajouterJoueur(Joueur("v2", "V2", Role.VILLAGEOIS_SIMPLE))

        val issue = arbitre.verifierFinDePartie()
        assertEquals(IssuePartie.VICTOIRE_LOUPS, issue)
    }

    @Test
    @DisplayName("Parité 5 loups contre 5 villageois -> VICTOIRE_LOUPS")
    fun testPariteCinqContreCinq() {
        for (i in 1..5) {
            arbitre.ajouterJoueur(Joueur("l$i", "Loup $i", Role.LOUP_GAROU))
            arbitre.ajouterJoueur(Joueur("v$i", "Villageois $i", Role.VILLAGEOIS_SIMPLE))
        }

        val issue = arbitre.verifierFinDePartie()
        assertEquals(IssuePartie.VICTOIRE_LOUPS, issue)
    }

    // =========================================================================
    // 6. TESTS VICTOIRE DU VILLAGE, ÉGALITÉ ET PARTIE EN COURS
    // =========================================================================

    @Test
    @DisplayName("Tous les loups morts, villageois vivants -> VICTOIRE_VILLAGE")
    fun testVictoireVillage() {
        arbitre.ajouterJoueur(Joueur("l1", "Loup Mort", Role.LOUP_GAROU, estEnVie = false))
        arbitre.ajouterJoueur(Joueur("v1", "Villageois 1", Role.VILLAGEOIS_SIMPLE, estEnVie = true))
        arbitre.ajouterJoueur(Joueur("v2", "Villageois 2", Role.VOYANTE, estEnVie = true))

        val issue = arbitre.verifierFinDePartie()
        assertEquals(IssuePartie.VICTOIRE_VILLAGE, issue)
    }

    @Test
    @DisplayName("Double élimination totale : tous les joueurs sont morts -> EGALITE")
    fun testEgaliteDoubleElimination() {
        arbitre.ajouterJoueur(Joueur("l1", "Loup Mort", Role.LOUP_GAROU, estEnVie = false))
        arbitre.ajouterJoueur(Joueur("v1", "Villageois Mort", Role.VILLAGEOIS_SIMPLE, estEnVie = false))

        val issue = arbitre.verifierFinDePartie()
        assertEquals(IssuePartie.EGALITE, issue)
    }

    @Test
    @DisplayName("1 loup contre 2 villageois -> EN_COURS")
    fun testPartieEnCoursMajoriteVillage() {
        arbitre.ajouterJoueur(Joueur("l1", "Loup", Role.LOUP_GAROU, estEnVie = true))
        arbitre.ajouterJoueur(Joueur("v1", "Villageois 1", Role.VILLAGEOIS_SIMPLE, estEnVie = true))
        arbitre.ajouterJoueur(Joueur("v2", "Villageois 2", Role.SORCIERE, estEnVie = true, potionsMort = 1))

        val issue = arbitre.verifierFinDePartie()
        assertEquals(IssuePartie.EN_COURS, issue)
    }

    // =========================================================================
    // 7. TESTS EXHAUSTIFS DE LA TABLE DE VÉRITÉ (N <= 3)
    // =========================================================================

    @Test
    @DisplayName("Table de vérité : 3 joueurs (2 Loups, 1 Villageois) -> VICTOIRE_LOUPS")
    fun testTable3Joueurs2Loups1Villageois() {
        val a = ArbitrePartie()
        a.ajouterJoueur(Joueur("l1", "Loup 1", Role.LOUP_GAROU))
        a.ajouterJoueur(Joueur("l2", "Loup 2", Role.LOUP_GAROU))
        a.ajouterJoueur(Joueur("v1", "Sorciere", Role.SORCIERE, potionsMort = 1))

        val issue = a.evaluerEtatJeu()
        assertEquals(IssuePartie.VICTOIRE_LOUPS, issue)
        assertEquals(IssuePartie.VICTOIRE_LOUPS, a.issueActuelle)
    }

    @Test
    @DisplayName("Table de vérité : 3 joueurs (1 Loup, 2 Villageois) -> EN_COURS")
    fun testTable3Joueurs1Loup2Villageois() {
        val a = ArbitrePartie()
        a.ajouterJoueur(Joueur("l1", "Loup", Role.LOUP_GAROU))
        a.ajouterJoueur(Joueur("v1", "Villageois", Role.VILLAGEOIS_SIMPLE))
        a.ajouterJoueur(Joueur("v2", "Voyante", Role.VOYANTE))

        val issue = a.evaluerEtatJeu()
        assertEquals(IssuePartie.EN_COURS, issue)
        assertEquals(IssuePartie.EN_COURS, a.issueActuelle)
    }

    @Test
    @DisplayName("Table de vérité : 2 joueurs (1 Loup, 1 Sorcière avec poison) -> EN_COURS")
    fun testTable2Joueurs1Loup1SorciereAvecPoison() {
        val a = ArbitrePartie()
        a.ajouterJoueur(Joueur("l1", "Loup", Role.LOUP_GAROU))
        a.ajouterJoueur(Joueur("s1", "Sorciere", Role.SORCIERE, potionsMort = 1))

        assertEquals(IssuePartie.EN_COURS, a.evaluerEtatJeu())
    }

    @Test
    @DisplayName("Table de vérité : 2 joueurs (1 Loup, 1 Villageois Simple ou déchu) -> VICTOIRE_LOUPS")
    fun testTable2Joueurs1Loup1VillageoisSimple() {
        val a = ArbitrePartie()
        a.ajouterJoueur(Joueur("l1", "Loup", Role.LOUP_GAROU))
        a.ajouterJoueur(Joueur("v1", "Villageois", Role.VILLAGEOIS_SIMPLE))

        assertEquals(IssuePartie.VICTOIRE_LOUPS, a.evaluerEtatJeu())
    }

    @Test
    @DisplayName("Table de vérité : 2 joueurs (2 Loups, 0 Villageois) -> VICTOIRE_LOUPS")
    fun testTable2Joueurs2Loups0Villageois() {
        val a = ArbitrePartie()
        a.ajouterJoueur(Joueur("l1", "Loup 1", Role.LOUP_GAROU))
        a.ajouterJoueur(Joueur("l2", "Loup 2", Role.LOUP_GAROU))

        assertEquals(IssuePartie.VICTOIRE_LOUPS, a.evaluerEtatJeu())
    }

    @Test
    @DisplayName("Table de vérité : 2 joueurs (0 Loup, 2 Villageois) -> VICTOIRE_VILLAGE")
    fun testTable2Joueurs0Loup2Villageois() {
        val a = ArbitrePartie()
        a.ajouterJoueur(Joueur("v1", "Villageois 1", Role.VILLAGEOIS_SIMPLE))
        a.ajouterJoueur(Joueur("v2", "Villageois 2", Role.SORCIERE))

        assertEquals(IssuePartie.VICTOIRE_VILLAGE, a.evaluerEtatJeu())
    }

    @Test
    @DisplayName("Table de vérité : 1 joueur (1 Loup) -> VICTOIRE_LOUPS")
    fun testTable1Joueur1Loup() {
        val a = ArbitrePartie()
        a.ajouterJoueur(Joueur("l1", "Loup Solitaire", Role.LOUP_GAROU))

        assertEquals(IssuePartie.VICTOIRE_LOUPS, a.evaluerEtatJeu())
    }

    @Test
    @DisplayName("Table de vérité : 1 joueur (1 Villageois) -> VICTOIRE_VILLAGE")
    fun testTable1Joueur1Villageois() {
        val a = ArbitrePartie()
        a.ajouterJoueur(Joueur("v1", "Dernier Villageois", Role.VILLAGEOIS_SIMPLE))

        assertEquals(IssuePartie.VICTOIRE_VILLAGE, a.evaluerEtatJeu())
    }

    @Test
    @DisplayName("Table de vérité : 0 joueur -> EGALITE")
    fun testTable0JoueurEgalite() {
        val a = ArbitrePartie()
        assertEquals(IssuePartie.EGALITE, a.evaluerEtatJeu())
    }
}
