package com.lupusarena.engine

import com.lupusarena.engine.ui.VictimeCardMapper
import com.lupusarena.engine.ui.preparerVictimeCardUi
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class VictimeCardMapperTest {

    @Test
    @DisplayName("Les membres de la meute se reconnaissent entre eux et ne voient jamais Simple Villageois")
    fun `les loups se reconnaissent mutuellement et voient le role lupin`() {
        val loup1 = Joueur("l1", "Loup Noir", Role.LOUP_GAROU)
        val loupBlanc = Joueur("lb", "Loup Solitaire", Role.LOUP_BLANC)
        val villageois = Joueur("v1", "Jean", Role.VILLAGEOIS_SIMPLE)

        // Loup 1 regarde Loup Blanc
        val roleVuSurLoupBlanc = loupBlanc.determinerRoleVisiblePar(loup1)
        assertEquals("Loup Blanc", roleVuSurLoupBlanc)
        assertNotEquals("Simple Villageois", roleVuSurLoupBlanc)

        // Loup Blanc regarde Loup 1
        val roleVuSurLoup1 = loup1.determinerRoleVisiblePar(loupBlanc)
        assertEquals("Loup-Garou", roleVuSurLoup1)
        assertNotEquals("Simple Villageois", roleVuSurLoup1)

        // Un villageois regarde Loup 1 -> Rôle masqué ("Inconnu")
        val roleVuParVillageois = loup1.determinerRoleVisiblePar(villageois)
        assertEquals("Inconnu", roleVuParVillageois)
    }

    @Test
    @DisplayName("Un joueur mort révèle publiquement son rôle d'origine à tous")
    fun `un joueur mort revele son role d origine`() {
        val loup = Joueur("l1", "Loup", Role.LOUP_GAROU, estEnVie = false, carteEstRevelee = true)
        val villageois = Joueur("v1", "Jean", Role.VILLAGEOIS_SIMPLE)

        val roleVu = loup.determinerRoleVisiblePar(villageois)
        assertEquals("Loup-Garou", roleVu)
    }

    @Test
    @DisplayName("Interdiction stricte du ciblage fratricide entre loups la nuit")
    fun `interdiction du ciblage fratricide entre loups`() {
        val loup1 = Joueur("l1", "Loup 1", Role.LOUP_GAROU)
        val loup2 = Joueur("l2", "Loup 2", Role.LOUP_GAROU)
        val loupBlanc = Joueur("lb", "Loup Blanc", Role.LOUP_BLANC)
        val villageois = Joueur("v1", "Jean", Role.VILLAGEOIS_SIMPLE)

        // Loup 1 cible Loup 2 -> Interdit
        val uiLoup2 = preparerVictimeCardUi(cible = loup2, joueurConnecte = loup1)
        assertFalse(uiLoup2.estCiblable, "Un loup ne peut pas cibler un confrère loup")
        assertTrue(uiLoup2.iconeEstLoup)
        assertEquals("Loup-Garou", uiLoup2.roleAfficheTexte)

        // Loup 1 cible Loup Blanc -> Interdit la nuit commune
        val uiLoupBlanc = preparerVictimeCardUi(cible = loupBlanc, joueurConnecte = loup1)
        assertFalse(uiLoupBlanc.estCiblable, "Un loup ne peut pas cibler le Loup Blanc la nuit des loups")
        assertTrue(uiLoupBlanc.iconeEstLoup)
        assertEquals("Loup Blanc", uiLoupBlanc.roleAfficheTexte)

        // Loup 1 cible le Villageois -> Autorisé
        val uiVillageois = preparerVictimeCardUi(cible = villageois, joueurConnecte = loup1)
        assertTrue(uiVillageois.estCiblable, "Un loup peut cibler un villageois")
        assertFalse(uiVillageois.iconeEstLoup)
    }

    @Test
    @DisplayName("La voyante sonde un loup blanc et voit impérativement un simple villageois (leurre)")
    fun `la voyante sonde un loup blanc et voit imperativement un simple villageois`() {
        val voyante = Joueur("V", "Voyante", Role.VOYANTE)
        val loupBlanc = Joueur("LB", "LoupBlanc", Role.LOUP_BLANC)
        val loupNormal = Joueur("LG", "LoupGarou", Role.LOUP_GAROU)
        val villageois = Joueur("S", "SimpleV", Role.VILLAGEOIS_SIMPLE)
        val villageois2 = Joueur("S2", "SimpleV2", Role.VILLAGEOIS_SIMPLE)

        val agent = AgentSurveillance(mutableListOf(voyante, loupBlanc, loupNormal, villageois, villageois2))

        // 1. Sondage sur le Loup Blanc -> Leurre actif
        val visionLoupBlanc = agent.executerSondageVoyante("V", "LB")
        assertEquals(Role.VILLAGEOIS_SIMPLE, visionLoupBlanc, "La Voyante doit être leurrée et voir un Simple Villageois.")

        // 2. Vérification que l'état réel de la cible reste inchangé
        assertEquals(Role.LOUP_BLANC, loupBlanc.roleInitial)
        assertEquals(Role.LOUP_BLANC, loupBlanc.roleActif)
        assertTrue(loupBlanc.estEnVie)
        assertFalse(loupBlanc.carteEstRevelee)

        // 3. À sa mort, le village entier découvre la vérité (roleInitial)
        var roleReveleMort: Role? = null
        agent.onCarteReveleeListener = { event ->
            roleReveleMort = event.roleRevele
        }
        agent.declarerMort("LB")
        assertEquals(Role.LOUP_BLANC, roleReveleMort, "À la mort, le vrai rôle d'origine LOUP_BLANC est révélé au village.")
    }

    @Test
    @DisplayName("La voyante sonde un loup normal et voit LOUP_GAROU")
    fun `la voyante sonde un loup normal et voit loup garou`() {
        val voyante = Joueur("V", "Voyante", Role.VOYANTE)
        val loupNormal = Joueur("LG", "LoupGarou", Role.LOUP_GAROU)
        val v1 = Joueur("V1", "V1", Role.VILLAGEOIS_SIMPLE)
        val v2 = Joueur("V2", "V2", Role.VILLAGEOIS_SIMPLE)

        val agent = AgentSurveillance(mutableListOf(voyante, loupNormal, v1, v2))
        val vision = agent.executerSondageVoyante("V", "LG")
        assertEquals(Role.LOUP_GAROU, vision)
    }

    @Test
    @DisplayName("Cloisonnement strict : un Loup ne peut pas exécuter d'actions de Sorcière")
    fun testCloisonnementActionsSorcierePourLesLoups() {
        val loup = Joueur("l1", "Loup", Role.LOUP_GAROU)
        val sorciere = Joueur("s1", "Sorciere", Role.SORCIERE)
        val v1 = Joueur("v1", "V1", Role.VILLAGEOIS_SIMPLE)
        val v2 = Joueur("v2", "V2", Role.VILLAGEOIS_SIMPLE)

        val sup = SuperviseurDeJeu(mutableListOf(loup, sorciere, v1, v2))
        sup.lancerPartie()

        // Loup tente d'utiliser une potion de sorcière
        val sauvetageParLoup = sup.actionSorciereSauver("l1")
        assertFalse(sauvetageParLoup, "Un loup ne peut en aucun cas activer la potion de vie de la sorcière")

        val poisonParLoup = sup.actionSorcierePoison("l1", "v1")
        assertFalse(poisonParLoup, "Un loup ne peut en aucun cas empoisonner")
    }
}
