package com.loup.arbitre

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class GestionnaireDebatTest {

    @Test
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
}
