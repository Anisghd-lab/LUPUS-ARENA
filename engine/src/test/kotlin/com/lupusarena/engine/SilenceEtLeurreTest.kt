package com.lupusarena.engine

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class SilenceEtLeurreTest {

    @Test
    @DisplayName("La Voyante sonde un Loup Blanc et voit strictement un Simple Villageois (leurre)")
    fun `la voyante sonde un loup blanc et voit strictement un simple villageois`() {
        val voyante = Joueur("V", "Voyante", Role.VOYANTE)
        val loupBlanc = Joueur("LB", "LoupBlanc", Role.LOUP_BLANC)
        val loupGarou = Joueur("LG", "LoupGarou", Role.LOUP_GAROU)
        val simpleV = Joueur("SV", "Villageois", Role.VILLAGEOIS_SIMPLE)
        val simpleV2 = Joueur("SV2", "Villageois2", Role.VILLAGEOIS_SIMPLE)

        val agent = AgentSurveillance(mutableListOf(voyante, loupBlanc, loupGarou, simpleV, simpleV2))

        // Leurre : la voyante perçoit VILLAGEOIS_SIMPLE
        val roleVuLB = agent.executerSondageVoyante("V", "LB")
        assertEquals(Role.VILLAGEOIS_SIMPLE, roleVuLB)

        // Inspection d'un loup standard : perçu LOUP_GAROU
        voyante.visionsRestantes = 1
        voyante.roleActif = Role.VOYANTE
        val roleVuLG = agent.executerSondageVoyante("V", "LG")
        assertEquals(Role.LOUP_GAROU, roleVuLG)

        // Révélation post-mortem de la carte d'origine
        var cartePublique: Role? = null
        agent.onCarteReveleeListener = { event -> cartePublique = event.roleRevele }
        agent.declarerMort("LB")
        assertEquals(Role.LOUP_BLANC, cartePublique)
    }

    @Test
    @DisplayName("Un loup ne peut pas bâillonner un membre de la meute ni sa propre victime nocturne")
    fun `un loup ne peut pas baillonner un membre de la meute ni sa propre victime nocturne`() {
        val loupGarou = Joueur("LG", "Loup1", Role.LOUP_GAROU)
        val loupBlanc = Joueur("LB", "Loup2", Role.LOUP_BLANC)
        val victime = Joueur("V", "Victime", Role.VILLAGEOIS_SIMPLE)
        val cibleSilence = Joueur("S", "CibleSilence", Role.VILLAGEOIS_SIMPLE)
        val autreVillageois = Joueur("V2", "AutreVillageois", Role.VILLAGEOIS_SIMPLE)

        val superviseur = SuperviseurDeJeu(mutableListOf(loupGarou, loupBlanc, victime, cibleSilence, autreVillageois))
        superviseur.lancerPartie() // Passe en NUIT_LOUPS (pas de voyante)

        // Interdit de faire taire le loup blanc
        val silenceLoupBlanc = superviseur.actionFaireTaireJoueur("LG", "LB")
        assertFalse(silenceLoupBlanc, "Un loup ne peut pas réduire au silence un confrère loup.")

        // Dévore la victime
        val voteReussi = superviseur.actionVoteLoup("LG", "V")
        assertTrue(voteReussi)

        // Interdit de cibler par le silence la personne déjà condamnée à mort
        val silenceMemeVictime = superviseur.actionFaireTaireJoueur("LG", "V")
        assertFalse(silenceMemeVictime, "Un loup ne peut pas réduire au silence sa propre victime de la nuit.")

        // Autorisé sur un autre villageois innocent
        val silenceValide = superviseur.actionFaireTaireJoueur("LG", "S")
        assertTrue(silenceValide, "Un loup peut réduire au silence un autre villageois vivant.")
    }

    @Test
    @DisplayName("Le silence est appliqué à l'aube puis expire à la fin du crépuscule")
    fun `le silence est applique a l aube puis expire a la fin du crepuscule`() {
        val loup = Joueur("L", "Loup", Role.LOUP_GAROU)
        val victime = Joueur("V", "Victime", Role.VILLAGEOIS_SIMPLE)
        val bavard = Joueur("B", "Bavard", Role.VILLAGEOIS_SIMPLE)
        val temoin = Joueur("T", "Temoin", Role.VILLAGEOIS_SIMPLE)

        val superviseur = SuperviseurDeJeu(mutableListOf(loup, victime, bavard, temoin))
        var eventSilenceCapte: JoueurSilenceEvent? = null
        superviseur.onJoueurSilence = { eventSilenceCapte = it }

        superviseur.lancerPartie()

        superviseur.actionVoteLoup("L", "V")
        superviseur.actionFaireTaireJoueur("L", "B")
        superviseur.validerFinTourLoups() // Résolution aube

        // B a survécu à la nuit : il est bâillonné
        assertTrue(bavard.estReduitAuSilence, "Bavard doit être réduit au silence après l'aube.")
        assertNotNull(eventSilenceCapte)
        assertEquals("B", eventSilenceCapte?.joueurId)

        // Clôture du jour par les votes
        superviseur.ouvrirVotesVillage()
        superviseur.enregistrerVote("L", "T")
        superviseur.enregistrerVote("B", "T")
        superviseur.enregistrerVote("T", "L")

        // Dès que le vote est dépouillé, le silence est levé pour la nuit suivante
        assertFalse(bavard.estReduitAuSilence, "Le silence doit être réinitialisé à la fin du jour.")
    }

    @Test
    @DisplayName("Un joueur ciblé par le silence mais tué pendant la nuit n'applique pas d'état parasite")
    fun `un joueur cible par le silence mais tue la nuit n applique pas d etat parasite`() {
        val loup = Joueur("L", "Loup", Role.LOUP_GAROU)
        val victime = Joueur("V", "Victime", Role.VILLAGEOIS_SIMPLE)
        val sorciere = Joueur("S", "Sorcière", Role.SORCIERE)
        val temoin = Joueur("T", "Temoin", Role.VILLAGEOIS_SIMPLE)

        val superviseur = SuperviseurDeJeu(mutableListOf(loup, victime, sorciere, temoin))
        superviseur.lancerPartie()

        // Loup attaque la victime
        superviseur.actionVoteLoup("L", "V")
        // Loup tente de faire taire le témoin
        superviseur.actionFaireTaireJoueur("L", "T")
        superviseur.validerFinTourLoups()

        // Sorcière empoisonne le témoin
        superviseur.actionSorcierePoison("S", "T")

        // Le témoin est mort, donc estReduitAuSilence doit être false
        assertFalse(temoin.estEnVie)
        assertFalse(temoin.estReduitAuSilence, "Un joueur mort ne doit pas rester sous silence.")
    }
}
