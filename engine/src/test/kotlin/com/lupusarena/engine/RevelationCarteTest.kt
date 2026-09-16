package com.lupusarena.engine

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class RevelationCarteTest {

    @Test
    @DisplayName("La carte retournée affiche le rôle d'origine même si la Voyante était déchue")
    fun `la carte retournee affiche le role d origine meme si la voyante etait dechue`() {
        val voyante = Joueur("1", "Alice", Role.VOYANTE)
        val loup = Joueur("2", "Bob", Role.LOUP_GAROU)
        val v1 = Joueur("3", "Charlie", Role.VILLAGEOIS_SIMPLE)
        val v2 = Joueur("4", "David", Role.VILLAGEOIS_SIMPLE)

        val agent = AgentSurveillance(mutableListOf(voyante, loup, v1, v2))

        // À 4 joueurs, la voyante a 1 vision. Elle sonde Bob.
        agent.executerSondageVoyante("1", "2")
        assertEquals(0, voyante.visionsRestantes)
        assertEquals(Role.VILLAGEOIS_SIMPLE, voyante.roleActif) // Déchue en jeu
        assertEquals(Role.VOYANTE, voyante.roleInitial)         // Origine conservée

        // Alice meurt plus tard au vote du village
        var roleReveleAuVillage: Role? = null
        agent.onCarteReveleeListener = { event ->
            roleReveleAuVillage = event.roleRevele
        }

        agent.declarerMort("1")

        assertTrue(voyante.carteEstRevelee)
        // La carte révélée doit obligatoirement être sa carte d'origine
        assertEquals(Role.VOYANTE, roleReveleAuVillage)
    }

    @Test
    @DisplayName("La Sorcière sans potion révèle sa carte de Sorcière à sa mort")
    fun `la sorciere sans potions revele sa carte de sorciere a sa mort`() {
        val sorciere = Joueur("S", "Sarah", Role.SORCIERE)
        val loup = Joueur("L", "Loup", Role.LOUP_GAROU)
        val v1 = Joueur("V1", "V1", Role.VILLAGEOIS_SIMPLE)
        val v2 = Joueur("V2", "V2", Role.VILLAGEOIS_SIMPLE)

        val agent = AgentSurveillance(mutableListOf(sorciere, loup, v1, v2))

        // Consommation du poison sur V1
        agent.executerPoisonSorciere("S", "V1")
        // Sauvetage de V2 après mort
        v2.estEnVie = false
        agent.executerSauvetageSorciere("S", "V2")

        // La sorcière n'a plus de potion -> déchue
        assertEquals(Role.VILLAGEOIS_SIMPLE, sorciere.roleActif)

        var roleAffiche: Role? = null
        agent.onCarteReveleeListener = { event ->
            roleAffiche = event.roleRevele
        }

        // Sarah est attaquée et meurt
        agent.declarerMort("S")

        assertTrue(sorciere.carteEstRevelee)
        assertEquals(Role.SORCIERE, roleAffiche)
    }

    @Test
    @DisplayName("Double KO nocturne en 1v1 révèle les deux cartes et déclare l'égalité")
    fun `double KO nocturne en 1v1 revele les deux cartes et declare l egalite`() {
        val sorciere = Joueur("S", "Sarah", Role.SORCIERE)
        val loup = Joueur("L", "Loup", Role.LOUP_GAROU)

        val superviseur = SuperviseurDeJeu(
            mutableListOf(
                sorciere,
                loup,
                Joueur("V1", "V1", Role.VILLAGEOIS_SIMPLE),
                Joueur("V2", "V2", Role.VILLAGEOIS_SIMPLE)
            )
        )
        val cartesRevelees = mutableListOf<Role>()

        superviseur.onDiffuserCarteRetournee = { event ->
            cartesRevelees.add(event.roleRevele)
        }

        // Déclaration simultanée de mort en 1v1
        superviseur.agentSurveillance.declarerMorts(listOf("S", "L"))

        assertEquals(IssuePartie.EGALITE, superviseur.agentSurveillance.issueActuelle)
        assertTrue(cartesRevelees.contains(Role.SORCIERE))
        assertTrue(cartesRevelees.contains(Role.LOUP_GAROU))
    }
}
