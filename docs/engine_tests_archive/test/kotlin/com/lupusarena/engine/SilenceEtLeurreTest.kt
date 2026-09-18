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
    @DisplayName("1. Un Loup-Garou peut sélectionner un Loup Blanc pour le silence (bluff intra-meute)")
    fun `un loup garou peut selectionner un loup blanc pour le silence`() {
        val loupGarou = Joueur("LG", "Loup1", Role.LOUP_GAROU)
        val loupBlanc = Joueur("LB", "LoupBlanc", Role.LOUP_BLANC)
        val victime = Joueur("V", "Victime", Role.VILLAGEOIS_SIMPLE)
        val autreVillageois = Joueur("V2", "AutreVillageois", Role.VILLAGEOIS_SIMPLE)
        val troisiemeVillageois = Joueur("V3", "TroisiemeVillageois", Role.VILLAGEOIS_SIMPLE)

        val superviseur = SuperviseurDeJeu(mutableListOf(loupGarou, loupBlanc, victime, autreVillageois, troisiemeVillageois))
        superviseur.lancerPartie()

        val voteMort = superviseur.actionVoteLoup("LG", "V")
        assertTrue(voteMort, "Les loups doivent pouvoir voter pour dévorer le villageois.")

        // Les loups peuvent cibler le Loup Blanc pour le silence (bluff intra-meute)
        val silenceLoupBlanc = superviseur.actionFaireTaireJoueur("LG", "LB")
        assertTrue(silenceLoupBlanc, "Un loup DOIT pouvoir réduire au silence son confrère Loup Blanc.")
        assertEquals("LB", superviseur.actionNuitEnCours.cibleSilenceId)

        // La validation réussit avec la double action proie + silence
        assertTrue(superviseur.validerFinTourLoups())
    }

    @Test
    @DisplayName("2. Un Loup-Garou peut se cibler lui-même avec actionFaireTaireJoueur (auto-mutisme)")
    fun `un loup garou peut se cibler lui-meme avec actionFaireTaireJoueur`() {
        val loupGarou = Joueur("LG", "Loup1", Role.LOUP_GAROU)
        val victime = Joueur("V", "Victime", Role.VILLAGEOIS_SIMPLE)
        val autreVillageois = Joueur("V2", "AutreVillageois", Role.VILLAGEOIS_SIMPLE)
        val temoin = Joueur("T", "Temoin", Role.VILLAGEOIS_SIMPLE)

        val superviseur = SuperviseurDeJeu(mutableListOf(loupGarou, victime, autreVillageois, temoin))
        superviseur.lancerPartie()

        superviseur.actionVoteLoup("LG", "V")

        // Auto-mutisme : le loup se fait taire lui-même
        val autoSilence = superviseur.actionFaireTaireJoueur("LG", "LG")
        assertTrue(autoSilence, "Un loup doit pouvoir s'auto-museler pour parfaire son alibi d'innocent.")
        assertEquals("LG", superviseur.actionNuitEnCours.cibleSilenceId)

        assertTrue(superviseur.validerFinTourLoups())
    }

    @Test
    @DisplayName("3. Le superviseur refuse de passer a la phase suivante si seule la mort a ete votee et pas le silence")
    fun `le superviseur refuse de passer a la phase suivante si seule la mort a ete votee et pas le silence`() {
        val loup = Joueur("L", "Loup", Role.LOUP_GAROU)
        val victime = Joueur("V", "Victime", Role.VILLAGEOIS_SIMPLE)
        val autreVillageois = Joueur("V2", "AutreVillageois", Role.VILLAGEOIS_SIMPLE)
        val temoin = Joueur("T", "Temoin", Role.VILLAGEOIS_SIMPLE)

        val superviseur = SuperviseurDeJeu(mutableListOf(loup, victime, autreVillageois, temoin))
        superviseur.lancerPartie()
        assertEquals(PhaseJeu.NUIT_LOUPS, superviseur.phaseActuelle)

        // Seule la mort est votée
        superviseur.actionVoteLoup("L", "V")
        assertNull(superviseur.actionNuitEnCours.cibleSilenceId)

        // Le superviseur refuse de clôturer le tour car la double action est obligatoire
        val finTourRefusee = superviseur.validerFinTourLoups()
        assertFalse(finTourRefusee, "Le tour des loups ne peut pas être validé sans avoir désigné une cible de silence.")
        assertEquals(PhaseJeu.NUIT_LOUPS, superviseur.phaseActuelle, "La phase doit rester NUIT_LOUPS.")

        // Tenter de cibler la proie pour le silence est également rejeté
        val silenceProie = superviseur.actionFaireTaireJoueur("L", "V")
        assertFalse(silenceProie, "Inutile et interdit de bâillonner un joueur déjà voué à mourir cette nuit.")

        // Désigner une cible de silence valide (un autre joueur vivant ou le loup lui-même)
        val silenceValide = superviseur.actionFaireTaireJoueur("L", "T")
        assertTrue(silenceValide)

        // Maintenant que les deux actions sont complètes, la transition est autorisée
        val finTourAcceptee = superviseur.validerFinTourLoups()
        assertTrue(finTourAcceptee, "La double action étant complète, la validation doit réussir.")
        assertNotEquals(PhaseJeu.NUIT_LOUPS, superviseur.phaseActuelle)
    }

    @Test
    @DisplayName("4. Le loup baillonne se voit attribuer estReduitAuSilence == true a l aube et son tour est saute par GestionnaireDebat")
    fun `le loup baillonne recoit estReduitAuSilence et son tour de parole est saute lors du debat`() {
        val loup1 = Joueur("L1", "Loup1", Role.LOUP_GAROU)
        val loup2 = Joueur("L2", "Loup2", Role.LOUP_GAROU)
        val victime = Joueur("V", "Victime", Role.VILLAGEOIS_SIMPLE)
        val temoin1 = Joueur("T1", "Temoin1", Role.VILLAGEOIS_SIMPLE)
        val temoin2 = Joueur("T2", "Temoin2", Role.VILLAGEOIS_SIMPLE)
        val temoin3 = Joueur("T3", "Temoin3", Role.VILLAGEOIS_SIMPLE)

        val superviseur = SuperviseurDeJeu(mutableListOf(loup1, loup2, victime, temoin1, temoin2, temoin3))
        superviseur.lancerPartie()

        // Les loups dévorent la victime V et bâillonnent le loup L2 pour son alibi
        superviseur.actionVoteLoup("L1", "V")
        val silenceL2 = superviseur.actionFaireTaireJoueur("L1", "L2")
        assertTrue(silenceL2)
        assertTrue(superviseur.validerFinTourLoups())

        // À l'aube (pas de sorcière), la nuit est résolue et le débat débute
        assertEquals(PhaseJeu.JOUR_DEBAT, superviseur.phaseActuelle)
        assertFalse(victime.estEnVie, "La victime V doit être morte.")
        assertTrue(loup2.estEnVie, "Le loup L2 est vivant.")
        assertTrue(loup2.estReduitAuSilence, "Le loup L2 doit être réduit au silence à l'aube.")

        val debat = superviseur.gestionnaireDebat
        assertNotNull(debat, "Le gestionnaire de débat doit être initialisé.")

        val orateursSautes = mutableListOf<String>()
        val orateursActifs = mutableListOf<String>()

        debat!!.onOrateurSauteCarMuet = { orateursSautes.add(it.id) }
        debat.onChangementOrateur = { orateursActifs.add(it.id) }

        debat.demarrerDebat()

        // L'ordre des vivants est L1, L2, T1, T2, T3
        // L1 prend la parole
        assertEquals("L1", debat.orateurActuel?.id)

        // L1 passe la parole -> L2 est bâillonné et doit être SAUTÉ automatiquement sans temps mort
        // La parole doit atterrir directement sur T1 !
        superviseur.passerParoleManuelle("L1")

        assertTrue(orateursSautes.contains("L2"), "Le loup L2 bâillonné doit être sauté automatiquement.")
        assertEquals("T1", debat.orateurActuel?.id, "La parole doit passer directement au témoin T1.")

        // Vérification de l'état UI généré
        val uiState = debat.genererUiState()
        val participantL2 = uiState.participants.first { it.id == "L2" }
        assertTrue(participantL2.estMuteForce, "L'état UI du loup L2 doit indiquer estMuteForce.")
        assertTrue(participantL2.iconeMuteVisible, "L'icône de mute doit être visible pour le loup L2.")
        assertFalse(participantL2.aLaParole, "Le loup L2 ne doit pas avoir la parole.")
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
