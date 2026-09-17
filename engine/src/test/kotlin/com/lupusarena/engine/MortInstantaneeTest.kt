package com.lupusarena.engine

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class MortInstantaneeTest {

    @Test
    @DisplayName("Mort instantanée émet de manière synchrone le rôle d'origine et la cause")
    fun testMortInstantaneeSynchroneRoleOrigine() {
        val sorciere = Joueur("s1", "Circé", Role.SORCIERE)
        val loup = Joueur("l1", "Fenrir", Role.LOUP_GAROU)
        val villageois = Joueur("v1", "Jean", Role.VILLAGEOIS_SIMPLE)

        // La sorcière a perdu ses potions et a été déchue en Simple Villageois
        sorciere.roleActif = Role.VILLAGEOIS_SIMPLE
        assertEquals(Role.VILLAGEOIS_SIMPLE, sorciere.roleActif)
        assertEquals(Role.SORCIERE, sorciere.roleInitial)

        val agent = AgentSurveillance(mutableListOf(sorciere, loup, villageois))
        val evenementsMorts = mutableListOf<MortInstantaneeEvent>()

        agent.onMortInstantaneeListener = { event ->
            evenementsMorts.add(event)
        }

        // Mort de la sorcière exécutée par le vote du village
        val mortSucces = agent.declarerMort("s1", CauseMort.VOTE_VILLAGE)
        assertTrue(mortSucces)
        assertFalse(sorciere.estEnVie)
        assertTrue(sorciere.carteEstRevelee)

        assertEquals(1, evenementsMorts.size)
        val event = evenementsMorts.first()
        assertEquals("s1", event.joueurId)
        assertEquals("Circé", event.joueurNom)
        // roleAffiche doit obligatoirement être le rôle d'origine
        assertEquals(Role.SORCIERE, event.roleAffiche)
        assertEquals(Camp.VILLAGE, event.camp)
        assertEquals(CauseMort.VOTE_VILLAGE, event.causeMort)
        assertTrue(event.timestamp > 0)
    }

    @Test
    @DisplayName("Résolution d'aube dans Superviseur : morts multiples avec causes distinctes")
    fun testSuperviseurMortsMultiplesCausesDistinctes() {
        val voyante = Joueur("v1", "Alice", Role.VOYANTE)
        val loup = Joueur("l1", "Bob", Role.LOUP_GAROU)
        val sorciere = Joueur("s1", "Charlie", Role.SORCIERE, potionsVie = 1, potionsMort = 1)
        val victimeLoups = Joueur("j1", "David", Role.VILLAGEOIS_SIMPLE)
        val innocent = Joueur("j2", "Eve", Role.VILLAGEOIS_SIMPLE)

        val superviseur = SuperviseurDeJeu(mutableListOf(voyante, loup, sorciere, victimeLoups, innocent))
        val flipsDiffuses = mutableListOf<MortInstantaneeEvent>()

        superviseur.onMortInstantanee = { event ->
            flipsDiffuses.add(event)
        }

        superviseur.lancerPartie()

        // Nuit : Voyante sonde
        superviseur.actionVoyante("v1", "l1")

        // Loups attaquent David ET musèlent Alice
        superviseur.actionVoteLoup("j1")
        superviseur.actionFaireTaireJoueur("l1", "v1")
        assertTrue(superviseur.validerFinTourLoups())

        // Sorcière n'utilise pas la potion de vie et empoisonne Bob le loup
        superviseur.actionSorcierePoison("s1", "l1")

        // À l'aube : David est mort de morsure, Bob est mort de poison
        assertFalse(victimeLoups.estEnVie)
        assertFalse(loup.estEnVie)

        assertEquals(2, flipsDiffuses.size)

        val eventDavid = flipsDiffuses.find { it.joueurId == "j1" }
        assertNotNull(eventDavid)
        assertEquals(CauseMort.MORSURE_LOUPS, eventDavid?.causeMort)
        assertEquals(Role.VILLAGEOIS_SIMPLE, eventDavid?.roleAffiche)

        val eventBob = flipsDiffuses.find { it.joueurId == "l1" }
        assertNotNull(eventBob)
        assertEquals(CauseMort.POISON_SORCIERE, eventBob?.causeMort)
        assertEquals(Role.LOUP_GAROU, eventBob?.roleAffiche)
        assertEquals(Camp.LOUPS, eventBob?.camp)
    }
}
