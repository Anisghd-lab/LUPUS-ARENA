package com.lupusarena.engine

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class SuperviseurDeJeuTest {

    private lateinit var joueurs: MutableList<Joueur>
    private lateinit var superviseur: SuperviseurDeJeu

    @BeforeEach
    fun setUp() {
        joueurs = mutableListOf(
            Joueur("v1", "Alice Voyante", Role.VOYANTE),
            Joueur("l1", "Bob Loup", Role.LOUP_GAROU),
            Joueur("s1", "Charlie Sorcière", Role.SORCIERE),
            Joueur("j1", "David Villageois", Role.VILLAGEOIS_SIMPLE)
        )
        superviseur = SuperviseurDeJeu(joueurs)
    }

    @Test
    @DisplayName("Refus de lancer une partie avec moins de 4 joueurs")
    fun testRefusMoinsDeQuatreJoueurs() {
        val joueursInsuffisants = mutableListOf(
            Joueur("j1", "P1", Role.LOUP_GAROU),
            Joueur("j2", "P2", Role.VILLAGEOIS_SIMPLE)
        )
        val sup = SuperviseurDeJeu(joueursInsuffisants)
        var messageJournal: String? = null
        sup.onJournalEvent = { messageJournal = it }

        sup.lancerPartie()
        assertEquals(PhaseJeu.EN_ATTENTE, sup.phaseActuelle)
        assertTrue(messageJournal?.contains("Nombre insuffisant") == true)
    }

    @Test
    @DisplayName("Cycle de nuit complet avec sauvetage de la Sorcière et victoire du Village par vote")
    fun testCycleCompletAvecSauvetageEtVote() {
        var phaseObservee: PhaseJeu? = null
        var issueObservee: IssuePartie? = null
        val journalLogs = mutableListOf<String>()

        superviseur.onPhaseChanged = { phaseObservee = it }
        superviseur.onGameOver = { issueObservee = it }
        superviseur.onJournalEvent = { journalLogs.add(it) }

        // 1. Lancement de la partie
        superviseur.lancerPartie()
        assertEquals(PhaseJeu.NUIT_VOYANTE, superviseur.phaseActuelle)
        assertEquals(1, superviseur.tourNumero)

        // 2. Tour de la Voyante : sonde le loup Bob
        val roleVu = superviseur.actionVoyante("v1", "l1")
        assertEquals(Role.LOUP_GAROU, roleVu)
        assertEquals(PhaseJeu.NUIT_LOUPS, superviseur.phaseActuelle)

        // 3. Tour des Loups : ciblent David ET musèlent Alice
        superviseur.actionVoteLoup("j1")
        superviseur.actionFaireTaireJoueur("l1", "v1")
        assertTrue(superviseur.validerFinTourLoups())
        assertEquals(PhaseJeu.NUIT_SORCIERE, superviseur.phaseActuelle)

        // 4. Tour de la Sorcière : sauve David avec sa potion de vie
        val sauvetageReussi = superviseur.actionSorciereSauver("s1")
        assertTrue(sauvetageReussi)
        // La résolution nocturne bascule automatiquement vers AUBE_BILAN puis JOUR_DEBAT
        assertEquals(PhaseJeu.JOUR_DEBAT, superviseur.phaseActuelle)
        assertTrue(joueurs.all { it.estEnVie }, "Tous les joueurs doivent être en vie car la Sorcière a sauvé la victime.")

        // 5. Débat & Ouverture des votes
        superviseur.ouvrirVotesVillage()
        assertEquals(PhaseJeu.JOUR_VOTE, superviseur.phaseActuelle)

        // 6. Les villageois votent majoritairement contre le loup Bob
        superviseur.enregistrerVote("v1", "l1")
        superviseur.enregistrerVote("s1", "l1")
        superviseur.enregistrerVote("j1", "l1")
        superviseur.enregistrerVote("l1", "v1") // Vote du loup

        // 7. Dépouillement automatique et arrêt autoritaire du jeu
        val loupBob = joueurs.first { it.id == "l1" }
        assertFalse(loupBob.estEnVie, "Bob le Loup doit être mort après exécution au vote.")
        assertEquals(PhaseJeu.TERMINEE, superviseur.phaseActuelle)
        assertEquals(IssuePartie.VICTOIRE_VILLAGE, issueObservee)
    }

    @Test
    @DisplayName("Sorcière utilise son poison de nuit pour éliminer un joueur")
    fun testSorciereEmpoisonneJoueur() {
        superviseur.lancerPartie()

        // Voyante agit
        superviseur.actionVoyante("v1", "j1")

        // Loups attaquent le villageois David ET musèlent la voyante Alice
        superviseur.actionVoteLoup("j1")
        superviseur.actionFaireTaireJoueur("l1", "v1")
        assertTrue(superviseur.validerFinTourLoups())

        // Sorcière décide d'empoisonner le loup Bob sans sauver David
        val poisonReussi = superviseur.actionSorcierePoison("s1", "l1")
        assertTrue(poisonReussi)

        // Résolution de l'aube : 2 morts (David dévoré, Bob empoisonné)
        val david = joueurs.first { it.id == "j1" }
        val bob = joueurs.first { it.id == "l1" }
        assertFalse(david.estEnVie)
        assertFalse(bob.estEnVie)

        // Comme l'unique loup est mort, la partie se termine immédiatement par victoire du Village
        assertEquals(PhaseJeu.TERMINEE, superviseur.phaseActuelle)
        assertEquals(IssuePartie.VICTOIRE_VILLAGE, superviseur.agentSurveillance.issueActuelle)
    }

    @Test
    @DisplayName("Égalité parfaite lors du vote du village : aucun joueur n'est éliminé")
    fun testEgaliteVotesAucuneExecution() {
        val v1 = Joueur("v1", "Alice Voyante", Role.VOYANTE)
        val l1 = Joueur("l1", "Bob Loup", Role.LOUP_GAROU)
        val s1 = Joueur("s1", "Charlie Sorcière", Role.SORCIERE)
        val j1 = Joueur("j1", "David Villageois", Role.VILLAGEOIS_SIMPLE)
        val j2 = Joueur("j2", "Eve Villageoise", Role.VILLAGEOIS_SIMPLE)
        val sup = SuperviseurDeJeu(mutableListOf(v1, l1, s1, j1, j2))

        sup.lancerPartie()
        sup.actionVoyante("v1", "j1")
        sup.actionVoteLoup("j1")
        sup.actionFaireTaireJoueur("l1", "v1")
        assertTrue(sup.validerFinTourLoups())
        sup.actionSorciereSauver("s1")

        sup.ouvrirVotesVillage()

        // Vote à égalité : 2 contre l1, 2 contre v1, 1 vote sur j2
        sup.enregistrerVote("v1", "l1")
        sup.enregistrerVote("s1", "l1")
        sup.enregistrerVote("j1", "v1")
        sup.enregistrerVote("l1", "v1")
        sup.enregistrerVote("j2", "j2")

        // Tous les joueurs restent vivants et on bascule sur la Nuit 2 (avec Voyante encore armée)
        assertTrue(sup.joueurs.all { it.estEnVie })
        assertEquals(2, sup.tourNumero)
        assertEquals(PhaseJeu.NUIT_VOYANTE, sup.phaseActuelle)
    }

    @Test
    @DisplayName("Arrêt immédiat lors de la domination des Loups (2 loups vs 1 villageois)")
    fun testDominationLoupsTroisJoueurs() {
        val joueurs3 = mutableListOf(
            Joueur("l1", "Loup 1", Role.LOUP_GAROU),
            Joueur("l2", "Loup 2", Role.LOUP_GAROU),
            Joueur("v1", "Villageois", Role.VILLAGEOIS_SIMPLE),
            Joueur("j_mort", "Mort", Role.VILLAGEOIS_SIMPLE, estEnVie = false)
        )
        var partieTerminee = false
        var issueFinale: IssuePartie? = null

        val sup = SuperviseurDeJeu(joueurs3)
        sup.onGameOver = {
            partieTerminee = true
            issueFinale = it
        }

        // Évaluation déclenchée dès l'arbitrage
        sup.agentSurveillance.evaluer()
        assertTrue(partieTerminee)
        assertEquals(PhaseJeu.TERMINEE, sup.phaseActuelle)
        assertEquals(IssuePartie.VICTOIRE_LOUPS, issueFinale)
    }

    @Test
    @DisplayName("Duel 1v1 : Double élimination simultanée nocturne -> EGALITE immédiate")
    fun testDuel1v1DoubleMortSimultaneeEgalite() {
        val duelJoueurs = mutableListOf(
            Joueur("l1", "Loup", Role.LOUP_GAROU),
            Joueur("s1", "Sorciere", Role.SORCIERE, potionsVie = 0, potionsMort = 1),
            Joueur("m1", "Mort 1", Role.VILLAGEOIS_SIMPLE, estEnVie = false),
            Joueur("m2", "Mort 2", Role.VILLAGEOIS_SIMPLE, estEnVie = false)
        )
        var issueGameOver: IssuePartie? = null
        val sup = SuperviseurDeJeu(duelJoueurs)
        sup.onGameOver = { issueGameOver = it }

        sup.lancerPartie()
        // Pas de voyante vivante -> directement NUIT_LOUPS
        assertEquals(PhaseJeu.NUIT_LOUPS, sup.phaseActuelle)

        // Loup attaque la sorcière ET s'auto-musèle pour le bluff (2 joueurs vivants)
        sup.actionVoteLoup("s1")
        sup.actionFaireTaireJoueur("l1", "l1")
        assertTrue(sup.validerFinTourLoups())
        assertEquals(PhaseJeu.NUIT_SORCIERE, sup.phaseActuelle)

        // La sorcière empoisonne le loup
        val empoisonne = sup.actionSorcierePoison("s1", "l1")
        assertTrue(empoisonne)

        // Résolution simultanée à l'aube : les deux meurent ensemble
        assertFalse(duelJoueurs[0].estEnVie)
        assertFalse(duelJoueurs[1].estEnVie)
        assertEquals(PhaseJeu.TERMINEE, sup.phaseActuelle)
        assertEquals(IssuePartie.EGALITE, sup.agentSurveillance.issueActuelle)
        assertEquals(IssuePartie.EGALITE, issueGameOver)
    }

    @Test
    @DisplayName("Sécurité : un joueur mort ne peut ni voter, ni agir, ni être sondé par lui-même")
    fun testSecuriteJoueurMortEtAutoSondage() {
        superviseur.lancerPartie()

        // 1. Voyante tente de s'auto-sonder
        val autoSondage = superviseur.actionVoyante("v1", "v1")
        assertNull(autoSondage, "Une voyante ne peut pas se sonder elle-même")
        assertEquals(PhaseJeu.NUIT_VOYANTE, superviseur.phaseActuelle)

        // Voyante sonde Bob
        superviseur.actionVoyante("v1", "l1")
        // Loup attaque David ET musèle Charlie
        superviseur.actionVoteLoup("j1")
        superviseur.actionFaireTaireJoueur("l1", "s1")
        assertTrue(superviseur.validerFinTourLoups())
        // Sorcière passe
        superviseur.passerTourSorciere()

        // À l'aube, David est mort
        val david = joueurs.first { it.id == "j1" }
        assertFalse(david.estEnVie)

        superviseur.ouvrirVotesVillage()

        // David (mort) tente de voter
        superviseur.enregistrerVote("j1", "l1")

        // Alice (vivante) tente de voter pour David (mort)
        superviseur.enregistrerVote("v1", "j1")

        // Le vote ne doit pas être clôturé car aucun vote valide n'a été enregistré
        assertEquals(PhaseJeu.JOUR_VOTE, superviseur.phaseActuelle)
    }

    @Test
    @DisplayName("Déchéance irréversible de la Sorcière et de la Voyante")
    fun testDecheanceIrreversible() {
        val sorciere = joueurs.first { it.id == "s1" }
        val voyante = joueurs.first { it.id == "v1" }

        // Initialement rôles actifs
        assertEquals(Role.SORCIERE, sorciere.role)
        assertEquals(Role.VOYANTE, voyante.role)

        // Consommation totale des visions de la Voyante
        voyante.visionsRestantes = 0
        superviseur.agentSurveillance.evaluer()
        assertEquals(Role.VILLAGEOIS_SIMPLE, voyante.role, "La Voyante sans vision doit être Simple Villageoise.")

        // Consommation totale des potions de la Sorcière
        sorciere.potionsVie = 0
        sorciere.potionsMort = 0
        superviseur.agentSurveillance.evaluer()
        assertEquals(Role.VILLAGEOIS_SIMPLE, sorciere.role, "La Sorcière sans potion doit être Simple Villageoise.")
    }

    @Test
    @DisplayName("Transition automatique et sans temps mort vers JOUR_VOTE des la fin de la file d'orateurs")
    fun testTransitionAutomatiqueFinDebatVersJourVote() {
        val capitaine = Joueur("c1", "Capitaine Charlie", Role.VILLAGEOIS_SIMPLE, estCapitaine = true)
        val villageois = Joueur("v1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val loup = Joueur("l1", "Bob", Role.LOUP_GAROU)
        val sorciere = Joueur("s1", "David", Role.SORCIERE)

        val sup = SuperviseurDeJeu(mutableListOf(capitaine, villageois, loup, sorciere), roomId = "room-arena-123")

        val phasesRecues = mutableListOf<PhaseJeu>()
        val emissionsFirebase = mutableListOf<Pair<String, Any>>()

        sup.onPhaseChanged = { phasesRecues.add(it) }
        sup.onEmissionFirebase = { path, value -> emissionsFirebase.add(path to value) }

        // Lancement du débat du village
        sup.lancerDebatDuVillage()
        assertEquals(PhaseJeu.JOUR_DEBAT, sup.phaseActuelle)

        val debat = sup.gestionnaireDebat
        assertNotNull(debat)

        // Déroulement complet de la file d'orateurs :
        // Le Capitaine ouvre, les autres parlent, le Capitaine clôture
        while (debat?.orateurActuel != null) {
            val orateur = debat.orateurActuel!!
            sup.passerParoleManuelle(orateur.id)
        }

        // VÉRIFICATIONS :
        // 1. Bascule automatique et instantanée vers JOUR_VOTE sans intervention manuelle de l'hôte
        assertEquals(PhaseJeu.JOUR_VOTE, sup.phaseActuelle)
        assertTrue(phasesRecues.contains(PhaseJeu.JOUR_VOTE))

        // 2. Émission temps réel vers Firebase (/rooms/{roomId}/currentPhase = "JOUR_VOTE")
        assertTrue(emissionsFirebase.any { it.first == "/rooms/room-arena-123/currentPhase" && it.second == "JOUR_VOTE" })

        // 3. Table des votes réinitialisée et prête
        assertTrue(sup.votesActuels.isEmpty())
    }

    @Test
    @DisplayName("Expiration du timer global de debat : bascule automatique vers JOUR_VOTE sans blocage")
    fun testExpirationTimerDebatBasculeAutomatiqueVersJourVote() {
        val villageois = Joueur("v1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val loup = Joueur("l1", "Bob", Role.LOUP_GAROU)
        val voyante = Joueur("s1", "Charlie", Role.VOYANTE)
        val sup = SuperviseurDeJeu(mutableListOf(villageois, loup, voyante), roomId = "room-timer-99")

        val emissions = mutableListOf<Pair<String, Any>>()
        sup.onEmissionFirebase = { path, value ->
            emissions.add(path to value)
        }

        sup.lancerDebatDuVillage()
        assertEquals(PhaseJeu.JOUR_DEBAT, sup.phaseActuelle)

        // Expiration du temps alloué au débat
        sup.forcerFinDebatSurExpirationTemps()

        // Transition immédiate vers JOUR_VOTE
        assertEquals(PhaseJeu.JOUR_VOTE, sup.phaseActuelle)
        assertTrue(emissions.any { it.first == "/rooms/room-timer-99/currentPhase" && it.second == "JOUR_VOTE" })
        assertTrue(emissions.any { it.first == "/rooms/room-timer-99/timerSeconds" && it.second == 15 })
        assertTrue(sup.votesActuels.isEmpty())
    }

    @Test
    @DisplayName("1. Depouillement anticipe : des que le 4e vivant sur 4 vote, execution immediate sans attendre la fin du chrono")
    fun testDepouillementAnticipeDesQueTousOntVote() {
        val j1 = Joueur("j1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val j2 = Joueur("j2", "Bob", Role.LOUP_GAROU)
        val j3 = Joueur("j3", "Charlie", Role.VOYANTE)
        val j4 = Joueur("j4", "David", Role.SORCIERE)

        val sup = SuperviseurDeJeu(mutableListOf(j1, j2, j3, j4))
        sup.lancerDebatDuVillage()
        sup.ouvrirVotesVillage()
        assertEquals(PhaseJeu.JOUR_VOTE, sup.phaseActuelle)
        assertEquals(4, sup.joueurs.count { it.estEnVie })

        // 3 joueurs votent contre Bob le loup (le vote n'est pas encore complet)
        sup.enregistrerVote("j1", "j2")
        assertEquals(PhaseJeu.JOUR_VOTE, sup.phaseActuelle)
        sup.enregistrerVote("j3", "j2")
        assertEquals(PhaseJeu.JOUR_VOTE, sup.phaseActuelle)
        sup.enregistrerVote("j4", "j2")
        assertEquals(PhaseJeu.JOUR_VOTE, sup.phaseActuelle)

        // Dès que le 4e joueur (j2) vote, le dépouillement et l'exécution se déclenchent immédiatement
        sup.enregistrerVote("j2", "j1")

        // La phase n'est plus JOUR_VOTE
        assertNotEquals(PhaseJeu.JOUR_VOTE, sup.phaseActuelle)
        // La victime (j2) meurt directement et sa carte est révélée
        assertFalse(j2.estEnVie, "Bob (j2) doit succomber sur-le-champ.")
        assertTrue(j2.carteEstRevelee, "La carte de Bob doit être révélée publiquement à tous les joueurs.")
    }

    @Test
    @DisplayName("2. Elimination du joueur le plus designe : estEnVie == false et carte revelee")
    fun testEliminationJoueurLePlusDesigne() {
        val j1 = Joueur("j1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val j2 = Joueur("j2", "Bob", Role.LOUP_GAROU)
        val j3 = Joueur("j3", "Charlie", Role.VOYANTE)
        val j4 = Joueur("j4", "David", Role.VILLAGEOIS_SIMPLE)

        val sup = SuperviseurDeJeu(mutableListOf(j1, j2, j3, j4))
        sup.lancerDebatDuVillage()
        sup.ouvrirVotesVillage()
        assertEquals(PhaseJeu.JOUR_VOTE, sup.phaseActuelle)

        var eventCarteCapture: RevelationCarteEvent? = null
        sup.onDiffuserCarteRetournee = { eventCarteCapture = it }

        // 3 voix contre David (j4), 1 voix contre Bob (j2)
        sup.enregistrerVote("j1", "j4")
        sup.enregistrerVote("j2", "j4")
        sup.enregistrerVote("j3", "j4")
        // 4e vote déclenche le dépouillement immédiat
        sup.enregistrerVote("j4", "j2")

        // David a reçu le plus de votes : éliminé et carte retournée
        assertFalse(j4.estEnVie, "David (j4) doit être éliminé par le vote.")
        assertTrue(j4.carteEstRevelee, "La carte de David doit être retournée.")
        assertNotNull(eventCarteCapture)
        assertEquals("j4", eventCarteCapture?.joueurId)
        assertEquals(Role.VILLAGEOIS_SIMPLE, eventCarteCapture?.roleRevele)
    }

    @Test
    @DisplayName("3. Expiration a 15s avec votes partiels : depouille les voix existantes et execute le joueur vise")
    fun testExpiration15sAvecVotesPartiels() {
        val j1 = Joueur("j1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val j2 = Joueur("j2", "Bob", Role.LOUP_GAROU)
        val j3 = Joueur("j3", "Charlie", Role.VOYANTE)
        val j4 = Joueur("j4", "David", Role.VILLAGEOIS_SIMPLE)

        val sup = SuperviseurDeJeu(mutableListOf(j1, j2, j3, j4))
        sup.lancerDebatDuVillage()
        sup.ouvrirVotesVillage()
        assertEquals(PhaseJeu.JOUR_VOTE, sup.phaseActuelle)

        // Seuls 2 joueurs sur 4 votent (j1 et j3 votent contre Bob j2)
        sup.enregistrerVote("j1", "j2")
        sup.enregistrerVote("j3", "j2")
        // j2 et j4 ne votent pas avant le temps imparti

        // Le chronomètre de 15s expire -> appel automatique
        sup.forcerFinScrutinSurExpiration()

        // Dépouillement des votes partiels et exécution immédiate
        assertNotEquals(PhaseJeu.JOUR_VOTE, sup.phaseActuelle)
        assertFalse(j2.estEnVie, "Bob le loup doit être exécuté avec la majorité des voix exprimées (2 contre 0).")
        assertTrue(j2.carteEstRevelee, "La carte de Bob doit être visible de tous.")
    }

    // =========================================================================
    // OPTION 1 : TESTS DE SUCCESSION DU CAPITAINE (TESTAMENT & PASSATION)
    // =========================================================================

    @Test
    @DisplayName("Option 1 : Le Capitaine tué par les loups à l'aube transmet son écharpe manuellement")
    fun testCapitaineMortNuitDeclencheSuccessionPuisDebat() {
        val cap = Joueur("c1", "Capitaine Charlie", Role.VILLAGEOIS_SIMPLE, estCapitaine = true)
        val loup = Joueur("l1", "Loup Larry", Role.LOUP_GAROU)
        val alice = Joueur("a1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val david = Joueur("d1", "David", Role.VILLAGEOIS_SIMPLE)
        val emma = Joueur("e1", "Emma", Role.VILLAGEOIS_SIMPLE)

        val sup = SuperviseurDeJeu(mutableListOf(cap, loup, alice, david, emma), roomId = "room-cap-1")
        sup.lancerPartie()

        // Tour de nuit : Voyante absente -> NUIT_LOUPS
        assertEquals(PhaseJeu.NUIT_LOUPS, sup.phaseActuelle)
        sup.actionVoteLoup("c1") // Le loup attaque le Capitaine Charlie
        sup.actionFaireTaireJoueur("d1") // Baillon sur David
        sup.validerFinTourLoups()

        // Pas de sorcière dans la partie -> Aube immédiate et détection de la mort du Capitaine
        assertEquals(PhaseJeu.CAPITAINE_SUCCESSION, sup.phaseActuelle)
        assertEquals("c1", sup.pendingCapitaineId)
        assertFalse(cap.estEnVie, "Charlie le Capitaine doit être mort.")
        assertTrue(cap.carteEstRevelee, "Sa carte doit être révélée.")

        // Le Capitaine mourant désigne Alice comme successeur
        val designationReussie = sup.designerSuccesseurCapitaine("c1", "a1")
        assertTrue(designationReussie)

        // Vérification du transfert immédiat des attributs
        assertFalse(cap.estCapitaine, "L'ancien Capitaine ne doit plus avoir le titre.")
        assertTrue(alice.estCapitaine, "Alice doit être la nouvelle Capitaine élue.")
        assertNull(sup.pendingCapitaineId)

        // Enchaînement automatique sans temps mort vers le débat
        assertEquals(PhaseJeu.JOUR_DEBAT, sup.phaseActuelle)
    }

    @Test
    @DisplayName("Option 1 : Expiration du timer de 10s transmet d'office l'écharpe au premier survivant")
    fun testCapitaineMortExpirationTransmetDoffice() {
        val cap = Joueur("c1", "Capitaine Charlie", Role.VILLAGEOIS_SIMPLE, estCapitaine = true)
        val loup = Joueur("l1", "Loup Larry", Role.LOUP_GAROU)
        val alice = Joueur("a1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val bob = Joueur("b1", "Bob", Role.VILLAGEOIS_SIMPLE)

        val sup = SuperviseurDeJeu(mutableListOf(cap, loup, alice, bob), roomId = "room-cap-timeout")
        sup.lancerDebatDuVillage()
        sup.ouvrirVotesVillage()

        // Le village vote contre le Capitaine Charlie
        sup.enregistrerVote("l1", "c1")
        sup.enregistrerVote("a1", "c1")
        sup.enregistrerVote("b1", "c1")
        sup.enregistrerVote("c1", "l1")

        // Dépouillement automatique car 4/4 ont voté -> Charlie exécuté -> CAPITAINE_SUCCESSION
        assertEquals(PhaseJeu.CAPITAINE_SUCCESSION, sup.phaseActuelle)
        assertEquals("c1", sup.pendingCapitaineId)

        // Le timer de 10s expire sans choix
        val forcerReussi = sup.forcerSuccessionCapitaineSurExpiration()
        assertTrue(forcerReussi)

        // Premier survivant dans l'ordre de la table (loup l1 ou alice a1)
        val nouveauCap = sup.joueurs.first { it.estEnVie && it.estCapitaine }
        assertNotNull(nouveauCap)
        assertNotEquals("c1", nouveauCap.id)
        assertFalse(cap.estCapitaine)

        // Enchaînement automatique vers la nuit suivante
        assertEquals(PhaseJeu.NUIT_LOUPS, sup.phaseActuelle)
        assertEquals(1, sup.tourNumero)
    }

    @Test
    @DisplayName("Option 1 : Le successeur hérite du vote double (poids = 2) au tour suivant")
    fun testNouveauCapitaineVoteDoubleAuTourSuivant() {
        val cap = Joueur("c1", "Capitaine Charlie", Role.VILLAGEOIS_SIMPLE, estCapitaine = true)
        val loup = Joueur("l1", "Loup Larry", Role.LOUP_GAROU)
        val alice = Joueur("a1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val bob = Joueur("b1", "Bob", Role.VILLAGEOIS_SIMPLE)
        val david = Joueur("d1", "David", Role.VILLAGEOIS_SIMPLE)

        val sup = SuperviseurDeJeu(mutableListOf(cap, loup, alice, bob, david))
        sup.lancerDebatDuVillage()
        sup.ouvrirVotesVillage()

        // Charlie exécuté
        sup.enregistrerVote("l1", "c1")
        sup.enregistrerVote("a1", "c1")
        sup.enregistrerVote("b1", "c1")
        sup.enregistrerVote("d1", "c1")
        sup.enregistrerVote("c1", "l1")

        // Charlie lègue son titre à Alice
        sup.designerSuccesseurCapitaine("c1", "a1")
        assertTrue(alice.estCapitaine)

        // On passe la nuit
        sup.actionVoteLoup("b1")
        sup.actionFaireTaireJoueur("d1")
        sup.validerFinTourLoups()
        // Aube -> Bob meurt, reste Alice (Capitaine) et David vs Loup Larry (2 villageois vs 1 loup)
        // Débat puis vote
        sup.ouvrirVotesVillage()
        assertEquals(PhaseJeu.JOUR_VOTE, sup.phaseActuelle)

        // Alice (nouvelle Capitaine) vote contre Larry le Loup
        sup.enregistrerVote("a1", "l1")
        // David vote contre Larry
        sup.enregistrerVote("d1", "l1")
        // Larry vote contre Alice
        sup.enregistrerVote("l1", "a1")

        // Dépouillement : Alice a un vote poids 2 + David poids 1 (3 voix) -> Larry est exécuté !
        assertFalse(loup.estEnVie, "Le vote double d'Alice nouvelle Capitaine doit faire pencher la balance (3 contre 1).")
        assertEquals(PhaseJeu.TERMINEE, sup.phaseActuelle, "La mort du dernier loup doit mettre fin à la partie.")
    }

    // =========================================================================
    // OPTION 2 : TESTS DE LA NUIT DE LA SORCIÈRE (NUIT_SORCIERE)
    // =========================================================================

    @Test
    @DisplayName("Option 2 : Affichage de la victime des loups strictement réservé à la Sorcière active")
    fun testSorciereConsultationVictimeSecrete() {
        val sorciere = Joueur("s1", "Sorcière Sabrina", Role.SORCIERE, potionsVie = 1, potionsMort = 1)
        val loup = Joueur("l1", "Loup Larry", Role.LOUP_GAROU)
        val alice = Joueur("a1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val bob = Joueur("b1", "Bob", Role.VILLAGEOIS_SIMPLE)

        val sup = SuperviseurDeJeu(mutableListOf(sorciere, loup, alice, bob))
        sup.lancerPartie()

        sup.actionVoteLoup("a1")
        sup.actionFaireTaireJoueur("b1")
        sup.validerFinTourLoups()

        assertEquals(PhaseJeu.NUIT_SORCIERE, sup.phaseActuelle)

        // La Sorcière interroge la victime des loups -> Alice trouvée
        val victimeVueParSorciere = sup.obtenirVictimeDesLoupsPourSorciere("s1")
        assertNotNull(victimeVueParSorciere)
        assertEquals("a1", victimeVueParSorciere?.id)

        // Un joueur non-sorcière interroge -> null
        assertNull(sup.obtenirVictimeDesLoupsPourSorciere("l1"))
        assertNull(sup.obtenirVictimeDesLoupsPourSorciere("b1"))
    }

    @Test
    @DisplayName("Option 2 : Choix cumulatif (Vie + Mort) dans la même nuit et décrémentation stricte")
    fun testSorciereCumulPotionVieEtMortMemeNuit() {
        val sorciere = Joueur("s1", "Sorcière Sabrina", Role.SORCIERE, potionsVie = 1, potionsMort = 1)
        val loup1 = Joueur("l1", "Loup 1", Role.LOUP_GAROU)
        val loup2 = Joueur("l2", "Loup 2", Role.LOUP_GAROU)
        val alice = Joueur("a1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val bob = Joueur("b1", "Bob", Role.VILLAGEOIS_SIMPLE)

        val sup = SuperviseurDeJeu(mutableListOf(sorciere, loup1, loup2, alice, bob))
        sup.lancerPartie()

        sup.actionVoteLoup("a1") // Les loups attaquent Alice
        sup.actionFaireTaireJoueur("b1")
        sup.validerFinTourLoups()

        assertEquals(PhaseJeu.NUIT_SORCIERE, sup.phaseActuelle)

        // 1. La Sorcière sauve Alice SANS clôturer son tour
        val sauvetage = sup.actionSorciereSauver("s1", cloturerTour = false)
        assertTrue(sauvetage)
        assertEquals(PhaseJeu.NUIT_SORCIERE, sup.phaseActuelle, "La sorcière doit rester dans sa phase pour utiliser son poison.")
        assertEquals(0, sorciere.potionsVie)

        // 2. La Sorcière empoisonne Loup 2 ET clôture son tour
        val empoisonnement = sup.actionSorcierePoison("s1", "l2", cloturerTour = true)
        assertTrue(empoisonnement)
        assertEquals(0, sorciere.potionsMort)

        // 3. Résolution composite à l'aube
        assertTrue(alice.estEnVie, "Alice a été sauvée par la potion de vie.")
        assertFalse(loup2.estEnVie, "Loup 2 a succombé au poison de la Sorcière.")
        assertEquals(CauseMort.POISON_SORCIERE, loup2.causeMort)
        assertTrue(loup2.carteEstRevelee)

        // La sorcière n'a plus de potions : déchéance de rôle
        assertEquals(Role.VILLAGEOIS_SIMPLE, sorciere.roleActif)
        assertEquals(Role.SORCIERE, sorciere.roleInitial)
    }

    @Test
    @DisplayName("Option 2 : Poison sans sauvetage -> annonce composite de 2 morts à l'aube")
    fun testSorcierePoisonSansSauverDeuxMortsSimultanes() {
        val sorciere = Joueur("s1", "Sorcière Sabrina", Role.SORCIERE, potionsVie = 1, potionsMort = 1)
        val loup1 = Joueur("l1", "Loup 1", Role.LOUP_GAROU)
        val loup2 = Joueur("l2", "Loup 2", Role.LOUP_GAROU)
        val alice = Joueur("a1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val bob = Joueur("b1", "Bob", Role.VILLAGEOIS_SIMPLE)

        val sup = SuperviseurDeJeu(mutableListOf(sorciere, loup1, loup2, alice, bob))
        sup.lancerPartie()

        sup.actionVoteLoup("a1")
        sup.actionFaireTaireJoueur("b1")
        sup.validerFinTourLoups()

        // La Sorcière n'utilise pas sa potion de vie, mais utilise sa potion de mort sur loup2
        sup.actionSorcierePoison("s1", "l2", cloturerTour = true)

        // À l'aube : Alice (morsure loups) et Loup 2 (poison) doivent être tous deux morts
        assertFalse(alice.estEnVie)
        assertEquals(CauseMort.MORSURE_LOUPS, alice.causeMort)
        assertFalse(loup2.estEnVie)
        assertEquals(CauseMort.POISON_SORCIERE, loup2.causeMort)
    }

    // =========================================================================
    // OPTION 3 : TESTS DE CONDITION D'ARRÊT & BILAN FINAL (ARBITRE & SUPERVISEUR)
    // =========================================================================

    @Test
    @DisplayName("Option 3 : Victoire du Village dès l'élimination de tous les loups avec Bilan complet")
    fun testVictoireVillageTermineeEtBilanComplet() {
        val j1 = Joueur("j1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val j2 = Joueur("j2", "Bob", Role.LOUP_GAROU)
        val j3 = Joueur("j3", "Charlie", Role.VOYANTE)
        val j4 = Joueur("j4", "David", Role.VILLAGEOIS_SIMPLE)

        var bilanRecu: BilanPartie? = null
        val sup = SuperviseurDeJeu(mutableListOf(j1, j2, j3, j4), roomId = "room-victory-village").apply {
            onBilanPartie = { bilan -> bilanRecu = bilan }
        }

        sup.lancerDebatDuVillage()
        sup.ouvrirVotesVillage()

        // Tout le monde vote contre Bob l'unique loup
        sup.enregistrerVote("j1", "j2")
        sup.enregistrerVote("j2", "j1")
        sup.enregistrerVote("j3", "j2")
        sup.enregistrerVote("j4", "j2")

        assertEquals(PhaseJeu.TERMINEE, sup.phaseActuelle)
        assertNotNull(sup.bilanPartie)
        assertEquals(IssuePartie.VICTOIRE_VILLAGE, sup.bilanPartie?.issue)
        assertEquals(Camp.VILLAGE, sup.bilanPartie?.vainqueurCamp)
        assertEquals(3, sup.bilanPartie?.totalVivants)
        assertEquals(1, sup.bilanPartie?.totalMorts)
        assertEquals(3, sup.bilanPartie?.survivantsVillage)
        assertEquals(0, sup.bilanPartie?.survivantsLoups)

        // Vérification de la notification callback
        assertEquals(sup.bilanPartie, bilanRecu)
    }

    @Test
    @DisplayName("Option 3 : Victoire de la Meute par parité atteinte (nbLoups >= nbVillageois)")
    fun testVictoireLoupsParPariteEtBilan() {
        val loup1 = Joueur("l1", "Loup 1", Role.LOUP_GAROU)
        val loup2 = Joueur("l2", "Loup 2", Role.LOUP_GAROU)
        val v1 = Joueur("v1", "Villageois 1", Role.VILLAGEOIS_SIMPLE)
        val v2 = Joueur("v2", "Villageois 2", Role.VILLAGEOIS_SIMPLE)
        val v3 = Joueur("v3", "Villageois 3", Role.VILLAGEOIS_SIMPLE)

        val sup = SuperviseurDeJeu(mutableListOf(loup1, loup2, v1, v2, v3), roomId = "room-victory-wolves")
        sup.lancerDebatDuVillage()
        sup.ouvrirVotesVillage()

        // Le village vote contre v3 -> il reste 2 Loups et 2 Villageois -> Parité (2 >= 2) !
        sup.enregistrerVote("l1", "v3")
        sup.enregistrerVote("l2", "v3")
        sup.enregistrerVote("v1", "v3")
        sup.enregistrerVote("v2", "v3")
        sup.enregistrerVote("v3", "l1")

        assertEquals(PhaseJeu.TERMINEE, sup.phaseActuelle)
        assertEquals(IssuePartie.VICTOIRE_LOUPS, sup.bilanPartie?.issue)
        assertEquals(Camp.LOUPS, sup.bilanPartie?.vainqueurCamp)
        assertEquals(2, sup.bilanPartie?.survivantsLoups)
        assertEquals(2, sup.bilanPartie?.survivantsVillage)
    }

    @Test
    @DisplayName("Option 3 : Parité 1v1 avec Sorcière armée de poison maintient la partie EN_COURS")
    fun testParite1v1SorciereArmeeMaintientEnCours() {
        val loup = Joueur("l1", "Loup", Role.LOUP_GAROU)
        val sorciere = Joueur("s1", "Sorcière", Role.SORCIERE, potionsMort = 1)
        val v1 = Joueur("v1", "Villageois", Role.VILLAGEOIS_SIMPLE)

        val sup = SuperviseurDeJeu(mutableListOf(loup, sorciere, v1))
        sup.lancerDebatDuVillage()
        sup.ouvrirVotesVillage()

        // v1 est éliminé au vote -> reste 1 Loup et 1 Sorcière avec poison
        sup.enregistrerVote("l1", "v1")
        sup.enregistrerVote("s1", "v1")
        sup.enregistrerVote("v1", "l1")

        // La partie ne doit PAS être terminée car la Sorcière peut encore abattre le Loup cette nuit !
        assertNotEquals(PhaseJeu.TERMINEE, sup.phaseActuelle)
        assertTrue(loup.estEnVie)
        assertTrue(sorciere.estEnVie)
    }
}
