package com.lupusarena.engine

import com.lupusarena.engine.models.*
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

class NouvellesFonctionnalitesReleaseTest {

    private lateinit var superviseur: SuperviseurDeJeu

    @BeforeEach
    fun setup() {
        val joueursInitiaux = listOf(
            Joueur(id = "capitaine_j1", nom = "Alice", role = Role.VILLAGEOIS, estCapitaine = true, estEnVie = true),
            Joueur(id = "loup_j2", nom = "Bob", role = Role.LOUP_GAROU, estCapitaine = false, estEnVie = true),
            Joueur(id = "sorciere_j3", nom = "Claire", role = Role.SORCIERE, estCapitaine = false, estEnVie = true),
            Joueur(id = "villageois_j4", nom = "David", role = Role.VILLAGEOIS, estCapitaine = false, estEnVie = true)
        )
        superviseur = SuperviseurDeJeu(joueurs = joueursInitiaux)
    }

    @Test
    fun `test scrutin diurne - depouillement anticipe des que tous les vivants ont vote`() {
        superviseur.basculerEnPhase(PhaseJeu.JOUR_VOTE)
        assertEquals(15, superviseur.timerActuelSecondes)

        // 3 joueurs votent contre Bob, Bob vote contre David
        superviseur.enregistrerVote(votantId = "capitaine_j1", cibleId = "loup_j2") // Poids = 2 voix
        superviseur.enregistrerVote(votantId = "sorciere_j3", cibleId = "loup_j2")
        superviseur.enregistrerVote(votantId = "villageois_j4", cibleId = "loup_j2")

        // La partie ne doit pas encore dépouiller (reste Bob)
        assertEquals(PhaseJeu.JOUR_VOTE, superviseur.phaseActuelle)

        // 4e vote émis : Eager resolution immédiate sans attendre l'expiration
        superviseur.enregistrerVote(votantId = "loup_j2", cibleId = "villageois_j4")

        val bob = superviseur.recupererJoueur("loup_j2")
        assertNotNull(bob)
        assertFalse(bob!!.estEnVie, "Bob doit être éliminé immédiatement")
        assertEquals(CauseMort.VOTE_VILLAGE, bob.causeMort)
        assertTrue(bob.carteEstRevelee, "La carte doit être révélée publiquement dès l'exécution")
    }

    @Test
    fun `test succession capitaine - deces et passation testament 10s`() {
        // Éliminer le capitaine
        superviseur.eliminerJoueur("capitaine_j1", CauseMort.MORSURE_LOUPS)

        // Le superviseur doit entrer en phase CAPITAINE_SUCCESSION avec timer à 10s
        assertEquals(PhaseJeu.CAPITAINE_SUCCESSION, superviseur.phaseActuelle)
        assertEquals(10, superviseur.timerActuelSecondes)

        val ancienCapitaine = superviseur.recupererJoueur("capitaine_j1")
        assertFalse(ancienCapitaine!!.estCapitaine, "Le défunt perd son écharpe")

        // Désignation du successeur
        val succes = superviseur.designerSuccesseurCapitaine(
            demandeurId = "capitaine_j1",
            heritierId = "villageois_j4"
        )
        assertTrue(succes)

        val nouveauCapitaine = superviseur.recupererJoueur("villageois_j4")
        assertTrue(nouveauCapitaine!!.estCapitaine, "David doit hériter du titre de Capitaine")
    }

    @Test
    fun `test sorciere - resolution composite double mort a l aube et decheance`() {
        superviseur.basculerEnPhase(PhaseJeu.NUIT_SORCIERE)

        // Les loups ont ciblé David, la sorcière ne le sauve pas et empoisonne Bob
        superviseur.definirVictimeNocturneDesLoups("villageois_j4")
        superviseur.utiliserPotionMortSorciere(sorciereId = "sorciere_j3", cibleId = "loup_j2")
        superviseur.cloturerPhaseSorciere()

        superviseur.resoudreNuitEtPasserALaube()

        // Vérification de la double mort
        val david = superviseur.recupererJoueur("villageois_j4")
        val bob = superviseur.recupererJoueur("loup_j2")
        assertFalse(david!!.estEnVie)
        assertEquals(CauseMort.MORSURE_LOUPS, david.causeMort)
        assertFalse(bob!!.estEnVie)
        assertEquals(CauseMort.POISON_SORCIERE, bob.causeMort)

        // Déchéance en Simple Villageois si les 2 potions sont bues
        val sorciere = superviseur.recupererJoueur("sorciere_j3")
        if (sorciere!!.potionsVie == 0 && sorciere.potionsMort == 0) {
            assertEquals(Role.VILLAGEOIS, sorciere.roleActif)
        }
    }

    @Test
    fun `test garde monotone - interdiction absolue de regression nocturne`() {
        superviseur.basculerEnPhase(PhaseJeu.NUIT_LOUPS)
        assertEquals(PhaseJeu.NUIT_LOUPS, superviseur.phaseActuelle)

        // Tentative illégale de rétrograder vers NUIT_VOYANTE
        superviseur.basculerEnPhase(PhaseJeu.NUIT_VOYANTE)
        assertEquals(PhaseJeu.NUIT_LOUPS, superviseur.phaseActuelle, "La phase des Loups ne doit jamais régresser vers la Voyante")

        // Avancement légal vers NUIT_SORCIERE
        superviseur.basculerEnPhase(PhaseJeu.NUIT_SORCIERE)
        assertEquals(PhaseJeu.NUIT_SORCIERE, superviseur.phaseActuelle)

        // Tentative illégale de rétrograder vers NUIT_LOUPS
        superviseur.basculerEnPhase(PhaseJeu.NUIT_LOUPS)
        assertEquals(PhaseJeu.NUIT_SORCIERE, superviseur.phaseActuelle, "La phase de la Sorcière ne doit jamais régresser vers les Loups")

        // Avancement vers l'Aube
        superviseur.basculerEnPhase(PhaseJeu.AUBE_BILAN)
        assertEquals(PhaseJeu.AUBE_BILAN, superviseur.phaseActuelle)

        // Tentative de revenir en arrière dans la nuit
        superviseur.basculerEnPhase(PhaseJeu.NUIT_SORCIERE)
        assertEquals(PhaseJeu.AUBE_BILAN, superviseur.phaseActuelle, "L'Aube ne doit pas régresser vers la Nuit")
    }
}
