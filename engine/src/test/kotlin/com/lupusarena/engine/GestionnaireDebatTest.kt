package com.lupusarena.engine

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class GestionnaireDebatTest {

    @Test
    @DisplayName("La parole saute instantanement le joueur reduit au silence et va au suivant")
    fun `la parole saute instantanement le joueur reduit au silence et va au suivant`() {
        val j1 = Joueur("1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val j2 = Joueur("2", "Bob", Role.VILLAGEOIS_SIMPLE, estReduitAuSilence = true) // Bâillonné
        val j3 = Joueur("3", "Charlie", Role.VILLAGEOIS_SIMPLE)

        val orateursAyantEuLaParole = mutableListOf<String>()
        val orateursSautes = mutableListOf<String>()

        val debat = GestionnaireDebat(listOf(j1, j2, j3)).apply {
            onChangementOrateur = { orateursAyantEuLaParole.add(it.id) }
            onOrateurSauteCarMuet = { orateursSautes.add(it.id) }
        }

        // Tour 1 : Alice
        debat.demarrerDebat()
        assertEquals("1", debat.orateurActuel?.id)

        // Fin du tour d'Alice -> Bob est sauté -> Charlie prend la parole directement
        debat.passerAuProchainOrateur()

        // Bob a été sauté sans délai
        assertTrue(orateursSautes.contains("2"))
        // La parole est directement chez Charlie
        assertEquals("3", debat.orateurActuel?.id)
        assertEquals(listOf("1", "3"), orateursAyantEuLaParole)
    }

    @Test
    @DisplayName("Le premier orateur est saute d'emblee s'il est reduit au silence")
    fun testPremierOrateurMuetSauteImmediatement() {
        val j1 = Joueur("1", "Alice", Role.VILLAGEOIS_SIMPLE, estReduitAuSilence = true)
        val j2 = Joueur("2", "Bob", Role.VILLAGEOIS_SIMPLE)

        val sautes = mutableListOf<String>()
        val orateurs = mutableListOf<String>()

        val debat = GestionnaireDebat(listOf(j1, j2)).apply {
            onChangementOrateur = { orateurs.add(it.id) }
            onOrateurSauteCarMuet = { sautes.add(it.id) }
        }

        debat.demarrerDebat()

        assertEquals("2", debat.orateurActuel?.id)
        assertEquals(listOf("1"), sautes)
        assertEquals(listOf("2"), orateurs)
    }

    @Test
    @DisplayName("Saut en cascade de plusieurs orateurs muets consecutifs")
    fun testSautEnCascadeOrateursMuets() {
        val j1 = Joueur("1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val j2 = Joueur("2", "Bob", Role.VILLAGEOIS_SIMPLE, estReduitAuSilence = true)
        val j3 = Joueur("3", "Charlie", Role.VILLAGEOIS_SIMPLE, estReduitAuSilence = true)
        val j4 = Joueur("4", "David", Role.VILLAGEOIS_SIMPLE)

        val sautes = mutableListOf<String>()
        val orateurs = mutableListOf<String>()
        var debatTermine = false

        val debat = GestionnaireDebat(listOf(j1, j2, j3, j4)).apply {
            onChangementOrateur = { orateurs.add(it.id) }
            onOrateurSauteCarMuet = { sautes.add(it.id) }
            onFinDuDebat = { debatTermine = true }
        }

        debat.demarrerDebat()
        assertEquals("1", debat.orateurActuel?.id)

        // Alice cède sa parole -> Bob puis Charlie sautés -> David prend la parole
        debat.passerAuProchainOrateur()
        assertEquals("4", debat.orateurActuel?.id)
        assertEquals(listOf("2", "3"), sautes)
        assertEquals(listOf("1", "4"), orateurs)

        // David cède sa parole -> Fin du débat
        debat.passerAuProchainOrateur()
        assertNull(debat.orateurActuel)
        assertTrue(debatTermine)
    }

    @Test
    @DisplayName("Generation fidele de l'etat UI du debat (DebatUiState)")
    fun testGenererUiState() {
        val j1 = Joueur("1", "Alice", Role.VILLAGEOIS_SIMPLE)
        val j2 = Joueur("2", "Bob", Role.VILLAGEOIS_SIMPLE, estReduitAuSilence = true)

        val debat = GestionnaireDebat(listOf(j1, j2), dureeParoleSecondes = 45)
        debat.demarrerDebat()

        val uiState = debat.genererUiState(tempsRestantSecondes = 40)
        assertEquals("1", uiState.orateurActuelId)
        assertEquals("Alice", uiState.orateurActuelNom)
        assertEquals(40, uiState.tempsRestantSecondes)
        assertEquals(2, uiState.participants.size)

        val p1 = uiState.participants.first { it.id == "1" }
        assertTrue(p1.aLaParole)
        assertFalse(p1.estMuteForce)
        assertFalse(p1.iconeMuteVisible)

        val p2 = uiState.participants.first { it.id == "2" }
        assertFalse(p2.aLaParole)
        assertTrue(p2.estMuteForce)
        assertTrue(p2.iconeMuteVisible)
    }

    @Test
    @DisplayName("Integration SuperviseurDeJeu : le debat saute la victime de silence et ouvre les votes")
    fun testSuperviseurIntegrationDebat() {
        val voyante = Joueur("v1", "Alice Voyante", Role.VOYANTE)
        val loup = Joueur("l1", "Bob Loup", Role.LOUP_GAROU)
        val sorciere = Joueur("s1", "Charlie Sorciere", Role.SORCIERE)
        val villageois = Joueur("j1", "David Villageois", Role.VILLAGEOIS_SIMPLE)

        val superviseur = SuperviseurDeJeu(mutableListOf(voyante, loup, sorciere, villageois))
        superviseur.lancerPartie()

        // Nuit : Voyante sonde
        superviseur.actionVoyante("v1", "l1")

        // Loups attaquent personne (ou attaquent Bob... mais attaquent David et bâillonnent Charlie)
        superviseur.actionVoteLoup("l1", "j1")
        superviseur.actionFaireTaireJoueur("l1", "s1") // Charlie la sorcière est bâillonnée !
        superviseur.validerFinTourLoups()

        // Sorcière sauve David
        superviseur.actionSorciereSauver("s1")

        // Résolution de l'aube -> Transition automatique vers JOUR_DEBAT via lancerDebatDuVillage()
        assertEquals(PhaseJeu.JOUR_DEBAT, superviseur.phaseActuelle)
        assertTrue(sorciere.estReduitAuSilence, "Charlie doit être réduite au silence.")

        val debat = superviseur.gestionnaireDebat
        assertNotNull(debat)

        // Orateur initial : Alice Voyante (v1)
        assertEquals("v1", debat?.orateurActuel?.id)

        // Bob Loup (l1) prend la parole ensuite
        superviseur.passerParoleManuelle("v1")
        assertEquals("l1", debat?.orateurActuel?.id)

        // Bob passe la parole -> Charlie (s1) est bâillonnée -> saut automatique immédiat vers David (j1)
        superviseur.passerParoleManuelle("l1")
        assertEquals("j1", debat?.orateurActuel?.id)

        // David passe la parole -> Tous ont parlé -> Clôture automatique du débat et ouverture des votes
        superviseur.passerParoleManuelle("j1")
        assertEquals(PhaseJeu.JOUR_VOTE, superviseur.phaseActuelle)
    }

    @Test
    @DisplayName("Le joueur reduit au silence au jour 1 reprend normalement la parole au debat du jour 2")
    fun testJoueurBaillonneJour1RetrouveParoleAuDebatJour2() {
        val voyante = Joueur("v1", "Alice", Role.VOYANTE)
        val loup = Joueur("l1", "Bob", Role.LOUP_GAROU)
        val sorciere = Joueur("s1", "Charlie", Role.SORCIERE, potionsVie = 1)
        val villageois1 = Joueur("j1", "David", Role.VILLAGEOIS_SIMPLE)
        val villageois2 = Joueur("j2", "Eve", Role.VILLAGEOIS_SIMPLE)

        val superviseur = SuperviseurDeJeu(mutableListOf(voyante, loup, sorciere, villageois1, villageois2))
        superviseur.lancerPartie()

        // Nuit 1 : Voyante sonde
        superviseur.actionVoyante("v1", "l1")

        // Loup attaque j1 et bâillonne Charlie (s1)
        superviseur.actionVoteLoup("l1", "j1")
        superviseur.actionFaireTaireJoueur("l1", "s1")
        superviseur.validerFinTourLoups()

        // Sorcière sauve David (j1)
        superviseur.actionSorciereSauver("s1")

        // Débat Jour 1 : Charlie est bâillonnée
        assertEquals(PhaseJeu.JOUR_DEBAT, superviseur.phaseActuelle)
        assertTrue(sorciere.estReduitAuSilence)

        // On ouvre les votes et on vote à égalité (aucun mort)
        superviseur.ouvrirVotesVillage()
        assertEquals(PhaseJeu.JOUR_VOTE, superviseur.phaseActuelle)
        superviseur.enregistrerVote("v1", "l1")
        superviseur.enregistrerVote("l1", "v1")
        superviseur.enregistrerVote("s1", "j1")
        superviseur.enregistrerVote("j1", "s1")
        superviseur.enregistrerVote("j2", "j2") // Égalité totale

        // Le crépuscule s'achève : fin du silence pour Charlie
        assertFalse(sorciere.estReduitAuSilence, "Le bâillon doit être retiré à l'issue de la journée.")
        assertEquals(2, superviseur.tourNumero)
        assertEquals(PhaseJeu.NUIT_VOYANTE, superviseur.phaseActuelle)

        // Nuit 2 : Voyante sonde j2
        superviseur.actionVoyante("v1", "j2")

        // Loups attaquent j1 mais NE bâillonnent personne cette fois
        superviseur.actionVoteLoup("l1", "j1")
        superviseur.validerFinTourLoups()

        // Sorcière passe son tour
        superviseur.passerTourSorciere()

        // David meurt de morsure
        assertFalse(villageois1.estEnVie)

        // Débat Jour 2 : Charlie est bien vivante et N'EST PLUS bâillonnée
        assertEquals(PhaseJeu.JOUR_DEBAT, superviseur.phaseActuelle)
        assertFalse(sorciere.estReduitAuSilence)

        val orateursDebat2 = mutableListOf<String>()
        val debat2 = superviseur.gestionnaireDebat
        debat2?.onChangementOrateur = { orateursDebat2.add(it.id) }

        // Tour 1 du Débat 2 : Alice (v1)
        assertEquals("v1", debat2?.orateurActuel?.id)

        // Alice passe la parole -> Bob (l1) prend la parole
        superviseur.passerParoleManuelle("v1")
        assertEquals("l1", debat2?.orateurActuel?.id)

        // Bob passe la parole -> Charlie (s1) n'est plus muette : elle prend la parole normalement !
        superviseur.passerParoleManuelle("l1")
        assertEquals("s1", debat2?.orateurActuel?.id)
        assertFalse(debat2?.orateurActuel?.estReduitAuSilence == true)
    }
}
