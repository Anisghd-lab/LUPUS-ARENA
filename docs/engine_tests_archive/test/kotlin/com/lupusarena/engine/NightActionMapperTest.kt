package com.lupusarena.engine

import com.lupusarena.engine.ui.NightActionMapper
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class NightActionMapperTest {

    @Test
    @DisplayName("Voyante : formatage dynamique du libellé et désactivation à 0 vision")
    fun testVoyanteUiState() {
        val voyante = Joueur("v1", "Voyante", Role.VOYANTE, visionsRestantes = 3)

        // 1. Plusieurs visions restantes
        val etat3 = NightActionMapper.construireEtatVoyante(voyante)
        assertEquals("Nuit de la Voyante", etat3.titrePhase)
        assertEquals("Sonder un joueur (3 restantes)", etat3.boutonPrimaire.texte)
        assertTrue(etat3.boutonPrimaire.isEnabled)
        assertTrue(etat3.boutonPrimaire.estVisible)
        assertFalse(etat3.boutonSecondaire.estVisible)
        assertTrue(etat3.boutonPasser.isEnabled)

        // 2. Une seule vision restante (accord singulier)
        voyante.visionsRestantes = 1
        val etat1 = NightActionMapper.construireEtatVoyante(voyante)
        assertEquals("Sonder un joueur (1 restante)", etat1.boutonPrimaire.texte)
        assertTrue(etat1.boutonPrimaire.isEnabled)

        // 3. Zéro vision restante -> bouton grisé
        voyante.visionsRestantes = 0
        voyante.role = Role.VILLAGEOIS_SIMPLE
        val etat0 = NightActionMapper.construireEtatVoyante(voyante)
        assertEquals("Sonder un joueur (0 restante)", etat0.boutonPrimaire.texte)
        assertFalse(etat0.boutonPrimaire.isEnabled, "Le bouton de sondage doit être désactivé si quota == 0")
    }

    @Test
    @DisplayName("Sorcière : affichage avec victime désignée et gestion des stocks de potions")
    fun testSorciereUiStateAvecVictimeEtPotions() {
        val sorciere = Joueur("s1", "Circé", Role.SORCIERE, potionsVie = 1, potionsMort = 1)

        // 1. Victime désignée "Mehdi" et 2 potions actives
        val etatAvecVictime = NightActionMapper.construireEtatSorciere(sorciere, "Mehdi")
        assertEquals("Nuit de la Sorcière", etatAvecVictime.titrePhase)
        assertEquals("Sauver Mehdi (Vie: 1)", etatAvecVictime.boutonPrimaire.texte)
        assertTrue(etatAvecVictime.boutonPrimaire.isEnabled)
        assertEquals("Empoisonner (Mort: 1)", etatAvecVictime.boutonSecondaire.texte)
        assertTrue(etatAvecVictime.boutonSecondaire.isEnabled)

        // 2. Aucune victime des loups cette nuit
        val etatSansVictime = NightActionMapper.construireEtatSorciere(sorciere, null)
        assertEquals("Sauver (Vie: 1)", etatSansVictime.boutonPrimaire.texte)
        assertFalse(etatSansVictime.boutonPrimaire.isEnabled, "Ne peut pas sauver s'il n'y a pas de victime.")

        // 3. Potion de vie épuisée (Vie: 0)
        sorciere.potionsVie = 0
        val etatSansVie = NightActionMapper.construireEtatSorciere(sorciere, "Mehdi")
        assertEquals("Sauver Mehdi (Vie: 0)", etatSansVie.boutonPrimaire.texte)
        assertFalse(etatSansVie.boutonPrimaire.isEnabled, "Bouton sauver désactivé si stock de vie à 0.")

        // 4. Potion de mort épuisée (Mort: 0)
        sorciere.potionsMort = 0
        val etatSansMort = NightActionMapper.construireEtatSorciere(sorciere, "Mehdi")
        assertEquals("Empoisonner (Mort: 0)", etatSansMort.boutonSecondaire.texte)
        assertFalse(etatSansMort.boutonSecondaire.isEnabled, "Bouton empoisonner désactivé si stock de poison à 0.")
    }
}
