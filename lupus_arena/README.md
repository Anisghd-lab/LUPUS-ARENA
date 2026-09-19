# 🐺 LUPUS ARENA — Jeu du Loup-Garou Vocal & Tactique en Temps Réel

[![Version](https://img.shields.io/badge/version-2.4.4%2B61-gold.svg)](https://github.com/Anisghd-lab/LUPUS-ARENA)
[![Flutter](https://img.shields.io/badge/Flutter-3.13%2B-blue.svg)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Realtime%20Database-orange.svg)](https://firebase.google.com)
[![Agora](https://img.shields.io/badge/Agora-RTC%20Voice-purple.svg)](https://www.agora.io)

Lupus Arena est une adaptation mobile haute performance du célèbre jeu des Loups-Garous, combinant audio spatialisé temps réel (Agora RTC Engine), synchronisation d'état atomique chiffrée (Firebase Realtime Database) et interface sombre obsidian/or gothique.

---

## 🚀 Notes de Version — Release v2.4.4 (Build 61)

### 🎭 Résolution du Bug du Voleur & Voleur d'Âmes (`ThiefHandler` & `SoulStealerHandler`)
- **Correction du Vol de Rôle en Direct / Multijoueur :**
  - **Démasquage du Rôle Réel :** Correction de la faille où le Voleur ne récupérait que le rôle public masqué (`simpleVillager`). Désormais, le rôle authentique de la cible est résolu soit par déchiffrement local du jeton, soit via le nœud sécurisé `secret_roles/$targetId/roleId`.
  - **Persistance Atomique dans `secret_roles` :** Mise à jour synchrone de `secret_roles/$thiefId/roleId` et `secret_roles/$targetId/roleId`, empêchant l'écouteur `_secretRoleSubscription` d'écraser immédiatement le rôle volé.
  - **Chiffrement du Trousseau (`encryptedRole`) :** Recalcul et ré-enregistrement des tokens chiffrés pour le voleur et sa victime.
  - **Transfert des Pouvoirs et Meute de Loups :** Si le Voleur subtilise un rôle de loup-garou, il est automatiquement intégré au `wolf_pack` et son canal audio de meute est synchronisé ; la victime en est exclue. Si le rôle volé est Sorcière ou Voyante, les potions et visions sont transférées et réinitialisées à zéro pour la victime.

### 🧩 Architecture Modulaire des Handlers (`lib/engine/handlers/`)
- **Création de `ThiefHandler` :** Implémentation complète de `RoleActionHandler` pour `GameRole.thief`, supportant le vol ciblé, le choix de cartes orphelines au centre et l'option de passer (`skip`).
- **Enregistrement dans `RoleHandlersRegistry` :** `GameRole.thief` et `GameRole.thiefOfHearts` sont désormais tous deux orchestrés via le registre des gestionnaires de rôles à pouvoirs.
- **Ajout de `actionStealerStealRole` dans `GameController` :** Le contrôleur d'état du moteur modulaire gère nativement le changement de rôles et de factions lors de l'étape `preStealer`.

### ⚡ Coordination des Phases & Interface Utilisateur (`BentoActionPanel`)
- **Prise en Compte de `thiefOfHearts` :** `GamePhaseCoordinator` et `ConditionalRoleDistributor` activent désormais correctement la phase `nightThief` si un Voleur d'Âmes est présent dans la partie.
- **Interface Réactive :** `BentoActionPanel` prend en charge l'affichage dynamique pour le Voleur et le Voleur d'Âmes, empêche l'auto-sélection du voleur et permet la validation fluide en mode joueur, hôte et DevMode.

### 🧪 Tests Unitaires et Validation
- Création de `test/thief_handlers_test.dart` validant les scénarios de vol, de choix de cartes et de passage.
- Enrichissement de `test/game_controller_engine_test.dart` avec la validation de l'action `preStealer`.

---

## 🚀 Notes de Version — Release v2.4.3 (Build 60)

### 🧠 Intégration du Moteur de Jeu Modulaire (`lib/engine/`)
- **Architecture Pure & Découplée (`GameController` & `game_engine_models.dart`) :**
  - Contrôleur universel réactif fondé sur `ChangeNotifier`, entièrement découplé de la persistance réseau, testable en isolation.
  - Ordonnancement canonique de nuit via une file dynamique (`Queue<GameStep>`) : Nuit préliminaire (Voleur, Cupidon) puis Nuit régulière (Comédien, Voyante, Renard, Corbeau, Pyromane, Salvateur, Loups, Grand Méchant Loup, Loup Blanc, Sorcière).
  - Vérification stricte de présence et survie (`_isRolePresentAndAlive`, `_areWerewolvesPresentAndAlive`) couplée au singleton `DeathRegistryService` pour interdire toute activation d'un rôle absent ou décédé.
- **Buffer d'Actions Non Destructif (`NightActionBuffer`) :**
  - Mémorisation et différé des attaques (`KillIntent`), boucliers (Salvateur), potions (Sorcière) et infections (Père des Loups), résolus de façon atomique au matin sans altération prématurée de l'état des joueurs.
  - Propagation instantanée du chagrin d'amour pour les amoureux liés.
- **Scrutin Diurne & Pouvoirs Spéciaux :**
  - Dépouillement des votes avec prise en compte de la double voix du Maire (`isCaptain`), des +2 voix automatiques du Corbeau, et de l'activation du Juge Bègue pour relancer un second vote dans la journée.
- **Cycle de Vie des Timers Sécurisé :**
  - Arrêt systématique (`_stopTimer()`) avant chaque transition d'état et lors du `dispose()`, garantissant l'absence de fuites mémoire ou d'exécutions asynchrones fantômes.

### 🧪 Suite Complète de Tests Unitaires (`test/game_controller_engine_test.dart`)
- Validation automatisée des phases préliminaires, de la séquence nocturne, de l'immunité octroyée par le Salvateur, des potions de la Sorcière, de la contagion amoureuse et de la victoire du village.

### 📋 Audit Complet de la Codebase (Fonctionnement, Logique & Performances)
- Publication du rapport d'audit exhaustif couvrant le sharding Firebase RTDB, la synchronisation sub-seconde `ServerTimeService`, la gestion Agora RTC, le verrou audio `LobbyAudioManager` et les optimisations graphiques `RepaintBoundary`.

---

## 🚀 Notes de Version — Release v2.4.2 (Build 59)

### ⚰️ Service Dédié Anti-Résurrection (`DeathRegistryService`) & Règle Absolue « Celui qui meurt meurt »
- **Fichier Dédié Singleton (`DeathRegistryService`) :** Centralisation absolue de l'état de mortalité dans un service autonome mondialement accessible à tous les composants, modèles et widgets (`PlayerModel`, `GameRoom`, `GameState`, `GameNotifier`, `BentoActionPanel`).
- **Verrouillage Inviolable des Scrutins & Débats :** Éradication totale des résurrections parasites durant le vote (`dayVoting`, `dayTieBreakVote`, `mayorElection`) et les prises de parole du Maire.
- **Désérialisation Blindée Multi-Niveau (`PlayerModel.fromMap` & `GameRoom.fromMap`) :** Tout joueur inscrit dans le registre a son statut `isAlive` irréversiblement fixé à `false`, peu importe les prétentions d'un paquet réseau ou snapshot Firebase.
- **Nœud Firebase `cemetery/` Synchronisé en Temps Réel :** Chaque écriture réseau `_syncState` ré-impose atomiquement l'état `players/$uid/isAlive: false` et `cemetery/$uid: true` pour chaque défunt.
- **Interdiction Formelle du Droit de Vote aux Morts :** `castVote` rejette immédiatement tout vote initié par un joueur décédé ou ciblant un joueur déjà mort.
- **Seule Exception Canonique :** Seule la potion de vie de la Sorcière (`allowWitchRevive`) appliquée avant l'aube peut réanimer un joueur du cimetière.

---

## 🚀 Notes de Version — Release v2.4.1 (Build 58)

### 🎵 Résolution Définitive de la Musique du Lobby (`LobbyAudioManager`)
- **Singleton Dédié & Verrou d'Arrêt Atomique (`_isExplicitlyStopped`) :** Implémentation du service singleton `LobbyAudioManager` avec protection synchrone de l'intention.
- **Attente Synchrone de Navigation (`await stopLobbyMusic()`) :** L'arrêt du moteur audio natif est systématiquement attendu (`await`) avant toute transition d'écran (`Navigator.pushReplacement`, création de salon, adhésion à une salle).
- **Protection du Cycle de Vie (`didChangeAppLifecycleState`) :** La reprise audio (`resumeLobbyMusic()`) n'est autorisée que si l'arrêt forcé n'a pas été demandé (`!_isExplicitlyStopped`) et si l'utilisateur est toujours sur l'accueil (`room == null`).

### ⚰️ Verrou d'Immortalité Inverse (`_cemeteryRegistry`) & Anti-Résurrection
- **Tombstone Local Inviolable :** Ajout du registre local `_cemeteryRegistry` dans `GameNotifier`. Tout joueur éliminé y est inscrit de façon permanente ; aucun snapshot réseau, cache local Firebase désynchronisé ou retour du mode Avion ne peut le ressusciter (`isAlive` est forcé à `false` et synchronisé en base de données via `_fixZombieOnDatabase`).
- **Exception Unique de la Sorcière :** Seule l'action salvatrice de la Sorcière (`applyWitchRevive`) sur la victime nocturne légitime retire le joueur du cimetière local.
- **Sécurisation de la Reconnexion (`handlePlayerReconnect` & `joinRoom`) :** Interdiction des valeurs par défaut aveugles (`?? true`). Ré-imposition explicite de l'état d'élimination du serveur et mise à jour exclusive des clés techniques de présence.
- **Désérialisation Blindée (`PlayerModel.fromMap`) :** Si `isAlive` est absent ou ambigu dans le paquet réseau reçu, le modèle applique rigoureusement `false` au lieu de ressusciter le joueur.
- **Préservation Post-Élection & Testament du Maire :** Ré-affirmation de l'état de mort de l'ensemble du registre `_cemeteryRegistry` lors de chaque élection ou passation d'écharpe.

---

## 🚀 Notes de Version — Release v2.4.0 (Build 57)

### 🛡️ Verrouillage Anti-Résurrection Absolu (Fix Post-Élection du Maire & Synchronisation Firebase)
- **Impossibilité de Résurrection :** Un joueur éliminé (`isAlive == false`) ne peut plus jamais revenir à la vie au cours de la partie, sous aucun prétexte, sauf par la potion de guérison miraculeuse de la Sorcière (`witchHealed`) sur la victime nocturne légitime.
- **Protection du Listener `players/` :** Le flux Firebase `_playersSubscription` ne peut plus écraser l'état de mort local par un snapshot partiel ou désynchronisé.
- **Ré-affirmation Explicite :** Lors de l'élection du Maire et de sa passation de pouvoir (testament), l'état `isAlive: false` de tous les défunts est re-confirmé dans les transactions atomiques.
- **Reconnexion Sécurisée (`joinRoom`) :** Les mises à jour de reconnexion s'exécutent désormais sur les clés feuilles individuelles, empêchant l'écrasement ou l'omission accidentelle du champ `isAlive` dans Firebase.

### 🎖️ Unification Totale : Titre Canonique de "Maire"
- **Dénomination Unique :** Harmonisation complète de tous les textes, boutons, journaux d'arène, badges et vues du jeu sous l'appellation officielle de **Maire** (remplaçant les dénominations hétérogènes "Capitaine", "Capitaine / Maire").
- **Élection & Testament :** « Élection du Maire », « Testament du Maire », « Succession du Maire », badge « ⭐ Maire (Voix double) ».

### 💘 Séquence Canonique de Cupidon & Suppression de Sous-Phase Redondante
- **Liaison Directe :** Cupidon unit les deux amants immédiatement lors de son action nocturne sans sous-phase intermédiaire : les statuts `isLover = true` et `loverId` sont instantanément synchronisés avec notifications directes.

### 🌫️ Brouillard de Guerre Strict (Fog of War & Badges Cachés)
- **Badge Amoureux :** Visible **uniquement** par Cupidon et par les deux amoureux eux-mêmes. Totalement masqué pour le reste du village et les autres spectateurs.
- **Badge Charmé :** Visible **uniquement** par le Joueur de Flûte et par l'ensemble des joueurs sous hypnose (qui se reconnaissent mutuellement).
- **Badge Infecté :** Visible exclusivement par la cible infectée et l'ensemble de la meute de loups.

### 🎵 Étanchéité Audio Absolue du Lobby
- **Cycle de Vie Strict :** La bande sonore `son-lupus.mp3` est rattachée au cycle de vie du Lobby via `WidgetsBindingObserver` : mise en pause automatique en arrière-plan et extinction immédiate lors de toute entrée en salon ou en arène.

---

## 🚀 Notes de Version — Release v2.3.9 (Build 56)

### 🐺 Loups-Garous : Sélection Séquentielle 2 Cibles (Dévorer + Museler) & Changement Fluide de Victime
- **Assignation Séquentielle en 2 Clics :** Le panneau tactique des loups fonctionne désormais selon le standard ergonomique de Cupidon et du Joueur de Flûte :
  * **1er clic :** Sélectionne la proie à **DÉVORER** (vote de meute / `nightVictimId`).
  * **2e clic :** Sélectionne le joueur à **MUSELER** (`blackWolfTargetId` / réduction au silence pour le jour suivant).
- **Changement de Proie par 2nd Clic :** Un second clic sur la même victime (ou directement sur l'emplacement Dévorer) annule la sélection et permet de choisir une autre victime en toute fluidité avant de museler.
- **Auto-Validation Instantanée :** Dès que les 2 cibles distinctes sont choisies, le tour est instantanément validé et passe à la phase suivante sans étape de confirmation superflue.
- **Résolution Nocturne Impérative :** La phase nocturne des loups se termine obligatoirement avec un joueur dévoré et un joueur muselé (attribution automatique de secours si le chronomètre expire).

### 🧙‍♀️ Sorcière : Verrouillage Strict de la Potion de Vie sur la Victime des Loups
- **Ciblage Exclusif de la Proie :** La potion de vie ne peut plus cibler de joueur arbitraire ; elle est strictement verrouillée sur la victime désignée par les loups (`nightVictimId`).
- **Choix Binaire (Sauver / Passer) :** La sorcière dispose du choix simple d'appliquer sa fiole (`✨ Sauver [Nom]`) ou de passer son tour (`🌙 Passer`). Si aucune proie n'existe, la potion reste grisée.
- **Liberté sur la Potion de Mort :** La potion de poison conserve sa sélection libre sur n'importe quel joueur vivant.
- **Usage Combiné & Rétrogradation :** Possibilité d'utiliser 0, 1 ou 2 potions dans la nuit avec rétrogradation automatique en Simple Villageois à l'épuisement total (0/0).

---

## 🚀 Notes de Version — Release v2.3.8 (Build 55)

### 🎵 Isolation Stricte de la Musique d'Ambiance au Menu d'Accueil (`room == null`)
- **Extinction Immédiate dès l'Entrée en Salle :** La bande-son `son-lupus.mp3` est strictement réservée au menu principal. Dès qu'un utilisateur crée, rejoint ou entre dans une salle (`room != null` : salon d'attente, partie simulée DevMode, ou arène en jeu), la musique est instantanément coupée pour laisser 100% de la bande passante et de la clarté sonore au chat vocal Agora RTC.
- **Reprise Exclusif au Retour Accueil :** La musique ne redémarre que lorsque l'utilisateur quitte définitivement la partie/salle pour revenir au menu principal.

### 🛡️ Rafraîchisseur d'Autorisations en Arrière-Plan & Auto-Récupération Agora
- **Moniteur d'Autorisations Invisible :** Intégration d'un service de rafraîchissement d'autorisations (Microphone, Bluetooth/Baffles, Notifications) tournant en arrière-plan et réactif aux cycles de vie de l'application (`AppLifecycleState.resumed`).
- **Auto-Réparation sans Redémarrage :** Détecte automatiquement l'octroi des permissions (suite à une mise à jour in-app, un retour des réglages système Android ou une boîte de dialogue) et réarme/reconnecte le moteur vocal Agora sans nécessiter de fermeture/réouverture manuelle de l'application.

---

## 🚀 Notes de Version — Release v2.3.7 (Build 54)

### 🧙‍♀️ Détection Robuste de la Victime des Loups & Sauvegarde de Secours (Sorcière)
- **Détection Automatique Renforcée :** Récupération dynamique et transparente de la proie désignée par la meute de loups (`nightVictimId` / calcul instantané des votes des loups y compris pour les bots et rôles masqués).
- **Mode de Sauvegarde de Secours (Fallback Manuel) :** Même si aucune proie n'a pu être synchronisée automatiquement (ou si la meute a voté blanc), la Sorcière peut désormais sélectionner manuellement n'importe quel joueur vivant sur la grille et déclencher `✨ Sauver [Nom]` en un clic direct.
- **Double Potion & Rétrogradation :** Maintien de l'usage combiné des deux potions (Vie & Mort) dans la même nuit avec bascule dynamique en simple villageoise dès épuisement des 2 fioles.

### 🎵 Optimisation Audio & AudioContext (`LupusAudioManager`)
- **Configuration AudioContext Android dédiée :** Configuration avec `AndroidContentType.music`, `AndroidUsageType.media` et `AndroidAudioFocus.none` pour empêcher le moteur RTC Agora de couper ou étouffer la musique d'ambiance.
- **Cycle de Vie Épuré (Lobby / Accueil) :** Suppression des appels redondants dans la méthode `build()`, remplacés par un listener d'état réactif propre (`ref.listen`) et initialisation post-frame callback.
- **Déclaration d'Asset Globale :** Fichier `assets/audio/son-lupus.mp3` référencé explicitement dans le bundle de l'application avec fallback gracieux sans blocage.

---

## 🚀 Notes de Version — Release v2.3.6 (Build 53)

### 🎵 Gestionnaire Audio Global (`LupusAudioManager`)
- **Musique d'ambiance immersive au Lobby / Menu :** Joue la bande originale `son-lupus.mp3` en boucle infinie dès l'arrivée sur le salon d'accueil.
- **Arrêt instantané en salle de jeu :** Coupe immédiatement et sans latence la musique dès l'entrée dans une salle d'attente ou arène de jeu, afin d'assurer une clarté totale pour les communications vocales Agora RTC.
- **Reprise automatique au retour :** Reprend la lecture automatiquement lors du retour au menu principal.
- **Architecture isolée & sécurisée :** Pattern Singleton protégé par try/catch pour garantir zéro crash, zéro interférence réseau/Firebase et zéro chevauchement de pistes.

### 🛡️ Correction Critique : Persistance des Morts & Cycle des Tours
- **Persistance stricte des éliminations :** Éradication du bug où des joueurs morts réapparaissaient vivants suite aux transitions de phase ou en Dev Mode (parsing booléen rigoureux contre les chaînes `'false'` et entiers `0` issus de Firebase RTDB).
- **Synchronisation atomique de l'état :** Préservation systématique des variables d'état de partie (`round`, `winner`, `isTieBreakActive`, `blackWolfTargetId`, `expandedRolesState`) lors des rafraîchissements locaux.
- **Affichage dynamique du compteur de tours :** Intégration réactive du tour (`Tour X` / `T{round}`) dans la barre supérieure et le badge de phase (bannière Stitch).

---

## 🚀 Notes de Version — Release v2.3.5 (Build 52)

### 🧙‍♀️ Sorcière : Utilisation Combinée des Potions, Cibles Intelligentes & Choix Libre (Oui/Non)

1. **Potion de Vie — Cible Automatique de la Victime des Loups :**
   - La Sorcière visualise instantanément la victime désignée par la meute de loups dans son panneau Bento, sans nécessiter de sélection manuelle sur la grille.
   - Un simple clic sur `✨ Sauver [Nom]` applique immédiatement la guérison.

2. **Potion de Mort — Liberté Totale de Choix :**
   - La Sorcière choisit librement n'importe quel joueur vivant sur la grille et peut déclencher `☠️ Empoisonner [Nom]` en un clic direct.

3. **Utilisation Combinée dans la Même Nuit & Liberté Totale (Oui / Non) :**
   - La Sorcière peut désormais utiliser **ses deux potions** (Vie & Mort) dans la même nuit si elle le souhaite.
   - L'utilisation des potions reste **strictement optionnelle** : la Sorcière peut choisir d'utiliser 0, 1 ou 2 potions.
   - Si la Sorcière utilise une potion mais souhaite conserver l'autre, ou ne rien faire du tout, un clic sur `🌙 Ne rien faire / Passer` ou `✓ Terminer mon tour` valide et passe immédiatement à la phase suivante sans forcer l'usage des potions restantes.

4. **Contrôle Permanent des Stocks & Rétrogradation en Simple Villageois :**
   - Vérification continue du nombre de potions restantes (`potionsVie` et `potionsMort`).
   - Dès que les 2 stocks atteignent 0 (`potionsVie == 0 && potionsMort == 0`), la Sorcière devient automatiquement **Simple Villageoise** (`GameRole.simpleVillager`).
   - Tant qu'il lui reste au moins 1 potion (`potionsVie > 0 || potionsMort > 0`), elle conserve l'intégralité de son statut de **Sorcière** (`GameRole.witch`).

---

## 🚀 Notes de Version — Release v2.3.4 (Build 51)

### 📌 Points Clés Modifiés :

1. **Principe Universel : Auto-Validation Directe & Zéro Phase Blanche :**
   - Dès qu'un joueur porteur d'un rôle actif effectue son action ou sélectionne le quota requis de joueur(s), l'action est **immédiatement** enregistrée et validée.
   - Suppression complète des étapes intermédiaires redondantes et des doubles validations par bouton "Valider".
   - Fin de timer / Timeout sécurisé : À l'expiration du chrono, toute sélection en cours est validée d'office ; en l'absence de sélection, une action nulle (SKIP) explicite est enregistrée sans bloquer ni corrompre l'état de la partie.

2. **Les Loups-Garous (Consensus & Synchronisation Temps Réel) :**
   - Tout tap/vote sur un joueur met à jour instantanément l'état partagé de la meute.
   - À l'expiration du timer, la cible ayant la majorité des voix est automatiquement désignée et validée (ou résolution explicite sans blocage en cas d'absence de vote).

3. **Le Pyromane (Imbiber & Enflammer Directs en 1 Clic) :**
   - Action d'imbibition immédiate dès qu'une cible est cliquée (1 joueur max) et passage direct à la phase suivante.
   - Tap direct sur "Enflammer" déclenchant instantanément l'embrasement de toutes les cibles précédemment imbibées.

4. **Cupidon & Joueur de Flûte (Sélection Multi-Cibles en 2 Clics Directs) :**
   - Clic 1 : Le 1er joueur est sélectionné visuellement (avec possibilité de le désélectionner au re-clic).
   - Clic 2 : Dès que le 2e joueur est cliqué, l'action est **automatiquement** validée et transmise sans bouton de confirmation intermédiaire.
   - Gestion sécurisée de fin de chrono : auto-complétion sécurisée en cas de sélection incomplète.

5. **La Sorcière (Action Unique Exclusive & Directe) :**
   - Règle absolue respectée : 1 seule potion par nuit (ou passer).
   - Trois choix directs et mutuellement exclusifs (1 seul clic pour chacun) :
     1. *"Sauver [NomVictime]"* $\to$ enregistrement immédiat et fin de tour instantanée.
     2. *"Empoisonner [NomCible]"* $\to$ enregistrement immédiat et fin de tour instantanée.
     3. *"Ne rien faire / Passer"* $\to$ enregistrement immédiat et passage direct à la suite.
   - Tout clic sur l'une de ces 3 options termine immédiatement le tour de la sorcière.

---

## 🛠️ Stack Technique

- **Framework :** Flutter (Dart 3.x)
- **State Management :** Riverpod (`StateNotifierProvider`)
- **Base de Données & Synchronisation :** Firebase Realtime Database
- **Audio & Microphones :** Agora RTC Engine
- **Sécurité :** Chiffrement HMAC-SHA256 pour les cartes secrètes
