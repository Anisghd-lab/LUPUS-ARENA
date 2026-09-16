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

        // 3. Tour des Loups : ciblent David
        superviseur.actionVoteLoup("j1")
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

        // Loups attaquent le villageois David
        superviseur.actionVoteLoup("j1")

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
        superviseur.lancerPartie()
        superviseur.actionVoyante("v1", "j1")
        superviseur.actionVoteLoup("j1")
        superviseur.actionSorciereSauver("s1")

        superviseur.ouvrirVotesVillage()

        // Vote éclaté à égalité 2 contre 2
        superviseur.enregistrerVote("v1", "l1")
        superviseur.enregistrerVote("s1", "l1")
        superviseur.enregistrerVote("j1", "v1")
        superviseur.enregistrerVote("l1", "v1")

        // Tous les joueurs restent vivants et on bascule sur la Nuit 2
        assertTrue(joueurs.all { it.estEnVie })
        assertEquals(2, superviseur.tourNumero)
        assertEquals(PhaseJeu.NUIT_VOYANTE, superviseur.phaseActuelle)
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

        // Loup attaque la sorcière
        sup.actionVoteLoup("s1")
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
        // Loup attaque David
        superviseur.actionVoteLoup("j1")
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
}
