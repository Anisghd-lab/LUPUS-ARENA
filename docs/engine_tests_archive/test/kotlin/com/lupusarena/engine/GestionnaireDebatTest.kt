package com.lupusarena.engine

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class GestionnaireDebatTest {

    // =========================================================================
    // NOUVELLES RÈGLES DE PRÉSÉANCE DU CAPITAINE (JOUR_DEBAT)
    // =========================================================================

    @Test
    @DisplayName("1. Capitaine vivant (C) et deux villageois (A, B) : ordre exact [C, A, B, C]")
    fun testCapitaineVivantEtDeuxVillageoisOrdreExact() {
        val joueurA = Joueur("A", "Alice", Role.VILLAGEOIS_SIMPLE)
        val joueurB = Joueur("B", "Bob", Role.VILLAGEOIS_SIMPLE)
        val joueurC = Joueur("C", "Charlie", Role.VILLAGEOIS_SIMPLE, estCapitaine = true)

        val orateurs = mutableListOf<String>()
        val ouvertures = mutableListOf<Boolean>()
        val clotures = mutableListOf<Boolean>()

        val debat = GestionnaireDebat(listOf(joueurA, joueurB, joueurC)).apply {
            onChangementOrateur = { orateur ->
                orateurs.add(orateur.id)
                ouvertures.add(estTourCapitaineOuverture)
                clotures.add(estTourCapitaineCloture)
            }
        }

        // Vérification de la liste ordonnée des tours planifiés
        assertEquals(listOf("C", "A", "B", "C"), debat.ordreDeParole.map { it.id })
        assertEquals(listOf("C", "A", "B", "C"), debat.orateursEffectifs.map { it.id })

        // Déroulement pas à pas de la parole
        debat.demarrerDebat()
        while (debat.orateurActuel != null) {
            debat.passerAuProchainOrateur()
        }

        // L'ordre effectif de prise de parole est strictement [C, A, B, C]
        assertEquals(listOf("C", "A", "B", "C"), orateurs)

        // Validation des états de tour :
        // 1er tour (C) -> ouverture=true, cloture=false
        // 2e tour (A)  -> ouverture=false, cloture=false
        // 3e tour (B)  -> ouverture=false, cloture=false
        // 4e tour (C)  -> ouverture=false, cloture=true
        assertEquals(listOf(true, false, false, false), ouvertures)
        assertEquals(listOf(false, false, false, true), clotures)
    }

    @Test
    @DisplayName("2. Capitaine C reduit au silence : saute au debut et a la fin, ordre devenant [A, B]")
    fun testCapitaineReduitAuSilenceSauteDebutEtFin() {
        val joueurA = Joueur("A", "Alice", Role.VILLAGEOIS_SIMPLE)
        val joueurB = Joueur("B", "Bob", Role.VILLAGEOIS_SIMPLE)
        val joueurC = Joueur("C", "Charlie", Role.VILLAGEOIS_SIMPLE, estCapitaine = true, estReduitAuSilence = true)

        val orateurs = mutableListOf<String>()
        val sautes = mutableListOf<String>()
        var finDuDebatAppelee = false

        val debat = GestionnaireDebat(listOf(joueurA, joueurB, joueurC)).apply {
            onChangementOrateur = { orateurs.add(it.id) }
            onOrateurSauteCarMuet = { sautes.add(it.id) }
            onFinDuDebat = { finDuDebatAppelee = true }
        }

        // orateursEffectifs exclut le capitaine bâillonné
        assertEquals(listOf("A", "B"), debat.orateursEffectifs.map { it.id })

        debat.demarrerDebat()
        while (debat.orateurActuel != null) {
            debat.passerAuProchainOrateur()
        }

        // L'ordre effectif devient [A, B]
        assertEquals(listOf("A", "B"), orateurs)

        // Le Capitaine a été sauté 2 fois (ouverture et fermeture) sans bloquer la file
        assertEquals(listOf("C", "C"), sautes)
        assertTrue(finDuDebatAppelee)
        assertNull(debat.orateurActuel)
    }

    @Test
    @DisplayName("3. Villageois intermediaire (A) muet : ordre devient [C, B, C]")
    fun testVillageoisIntermediaireMuetOrdreDevientCBC() {
        val joueurA = Joueur("A", "Alice", Role.VILLAGEOIS_SIMPLE, estReduitAuSilence = true)
        val joueurB = Joueur("B", "Bob", Role.VILLAGEOIS_SIMPLE)
        val joueurC = Joueur("C", "Charlie", Role.VILLAGEOIS_SIMPLE, estCapitaine = true)

        val orateurs = mutableListOf<String>()
        val sautes = mutableListOf<String>()

        val debat = GestionnaireDebat(listOf(joueurA, joueurB, joueurC)).apply {
            onChangementOrateur = { orateurs.add(it.id) }
            onOrateurSauteCarMuet = { sautes.add(it.id) }
        }

        // orateursEffectifs exclut le villageois A bâillonné
        assertEquals(listOf("C", "B", "C"), debat.orateursEffectifs.map { it.id })

        debat.demarrerDebat()
        while (debat.orateurActuel != null) {
            debat.passerAuProchainOrateur()
        }

        // L'ordre effectif devient [C, B, C]
        assertEquals(listOf("C", "B", "C"), orateurs)
        assertEquals(listOf("A"), sautes)
    }

    @Test
    @DisplayName("Capitaine identifie via joueur.roleActif == Role.CAPITAINE")
    fun testCapitaineIdentifieViaRoleActif() {
        val joueurA = Joueur("A", "Alice", Role.VILLAGEOIS_SIMPLE)
        val joueurB = Joueur("B", "Bob", Role.VILLAGEOIS_SIMPLE)
        val joueurC = Joueur("C", "Charlie", Role.CAPITAINE)

        val debat = GestionnaireDebat(listOf(joueurA, joueurB, joueurC))
        assertEquals(listOf("C", "A", "B", "C"), debat.ordreDeParole.map { it.id })

        val orateurs = mutableListOf<String>()
        debat.onChangementOrateur = { orateurs.add(it.id) }
        debat.demarrerDebat()
        while (debat.orateurActuel != null) {
            debat.passerAuProchainOrateur()
        }

        assertEquals(listOf("C", "A", "B", "C"), orateurs)
    }

    @Test
    @DisplayName("Capitaine mort : la file deroule les vivants standard [A, B]")
    fun testCapitaineMortDeroulementStandard() {
        val joueurA = Joueur("A", "Alice", Role.VILLAGEOIS_SIMPLE)
        val joueurB = Joueur("B", "Bob", Role.VILLAGEOIS_SIMPLE)
        val joueurC = Joueur("C", "Charlie", Role.VILLAGEOIS_SIMPLE, estCapitaine = true, estEnVie = false)

        val debat = GestionnaireDebat(listOf(joueurA, joueurB, joueurC))
        assertEquals(listOf("A", "B"), debat.ordreDeParole.map { it.id })

        val orateurs = mutableListOf<String>()
        debat.onChangementOrateur = { orateurs.add(it.id) }
        debat.demarrerDebat()
        while (debat.orateurActuel != null) {
            debat.passerAuProchainOrateur()
        }

        assertEquals(listOf("A", "B"), orateurs)
    }

    @Test
    @DisplayName("Validation de l'etat UI DebatUiState avec badges Capitaine ouverture et cloture")
    fun testDebatUiStateAvecBadgesCapitaine() {
        val joueurA = Joueur("A", "Alice", Role.VILLAGEOIS_SIMPLE)
        val joueurB = Joueur("B", "Bob", Role.VILLAGEOIS_SIMPLE)
        val joueurC = Joueur("C", "Charlie", Role.VILLAGEOIS_SIMPLE, estCapitaine = true)

        val debat = GestionnaireDebat(listOf(joueurA, joueurB, joueurC), dureeParoleSecondes = 30)

        // Tour 1 : Capitaine C ouverture
        debat.demarrerDebat()
        val ui1 = debat.genererUiState(tempsRestantSecondes = 25)
        assertEquals("C", ui1.orateurActuelId)
        assertTrue(ui1.estTourCapitaineOuverture)
        assertFalse(ui1.estTourCapitaineCloture)
        assertTrue(ui1.participants.first { it.id == "C" }.estCapitaine)
        assertEquals(3, ui1.participants.size)

        // Tour 2 : Villageois A
        debat.passerAuProchainOrateur()
        val ui2 = debat.genererUiState(tempsRestantSecondes = 20)
        assertEquals("A", ui2.orateurActuelId)
        assertFalse(ui2.estTourCapitaineOuverture)
        assertFalse(ui2.estTourCapitaineCloture)

        // Tour 3 : Villageois B
        debat.passerAuProchainOrateur()
        val ui3 = debat.genererUiState(tempsRestantSecondes = 15)
        assertEquals("B", ui3.orateurActuelId)
        assertFalse(ui3.estTourCapitaineOuverture)
        assertFalse(ui3.estTourCapitaineCloture)

        // Tour 4 : Capitaine C cloture
        debat.passerAuProchainOrateur()
        val ui4 = debat.genererUiState(tempsRestantSecondes = 10)
        assertEquals("C", ui4.orateurActuelId)
        assertFalse(ui4.estTourCapitaineOuverture)
        assertTrue(ui4.estTourCapitaineCloture)

        // Fin du debat
        debat.passerAuProchainOrateur()
        assertNull(debat.orateurActuel)
        val uiFin = debat.genererUiState(tempsRestantSecondes = 0)
        assertNull(uiFin.orateurActuelId)
        assertFalse(uiFin.estTourCapitaineOuverture)
        assertFalse(uiFin.estTourCapitaineCloture)
    }

    @Test
    @DisplayName("Tous reduits au silence : fin immediate sans cycle infini")
    fun testTousReduitsAuSilencePasDeCycleInfini() {
        val joueurA = Joueur("A", "Alice", Role.VILLAGEOIS_SIMPLE, estReduitAuSilence = true)
        val joueurC = Joueur("C", "Charlie", Role.VILLAGEOIS_SIMPLE, estCapitaine = true, estReduitAuSilence = true)

        var finDuDebatAppelee = false
        val sautes = mutableListOf<String>()

        val debat = GestionnaireDebat(listOf(joueurA, joueurC)).apply {
            onOrateurSauteCarMuet = { sautes.add(it.id) }
            onFinDuDebat = { finDuDebatAppelee = true }
        }

        debat.demarrerDebat()
        assertNull(debat.orateurActuel)
        assertTrue(finDuDebatAppelee)
        assertEquals(listOf("C", "A", "C"), sautes)

        // Appels subsequents a passerAuProchainOrateur restent sans effet
        debat.passerAuProchainOrateur()
        assertNull(debat.orateurActuel)
    }

    // =========================================================================
    // TESTS EXISTANTS DE NON-RÉGRESSION
    // =========================================================================

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

        // Loups attaquent David et bâillonnent Charlie
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

        // Loups attaquent j1 et bâillonnent j2 (ne bâillonnent pas Charlie s1)
        superviseur.actionVoteLoup("l1", "j1")
        superviseur.actionFaireTaireJoueur("l1", "j2")
        val tourLoupsValide = superviseur.validerFinTourLoups()
        assertTrue(tourLoupsValide)

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
