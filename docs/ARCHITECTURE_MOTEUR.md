# Architecture du Moteur de Règles — Lupus Arena

> Acte officiel de consolidation — 2026-09-18

## Source Unique de Vérité : Dart / Flutter

Depuis la migration de septembre 2026, l'intégralité de la logique de jeu
de Lupus Arena réside **EXCLUSIVEMENT** dans les fichiers Dart suivants :

| Fichier | Responsabilité |
|---|---|
| `lib/GameNotifier.dart` | Orchestrateur principal : phases, cycles nuit/jour, votes, résolutions, conditions de victoire |
| `lib/models/game_role.dart` | Définition canonique des 30 rôles (camp, priorité nocturne, type d'action) |
| `lib/models/game_room.dart` | Modèle de salle Firebase — sérialisation/désérialisation toMap()/fromMap() |
| `lib/models/expanded_roles_state.dart` | État Firebase des 17 rôles additionnels (Corbeau, Enfant Sauvage, Ancien, etc.) |
| `lib/services/expanded_roles_coordinator.dart` | Algorithmes purs d'arbitrage pour les 17 rôles canoniques |

---

## Algorithmes Canoniques Portés depuis le Moteur Kotlin

### 1. Quota de visions scalant de la Voyante
```
totalJoueurs ≤ 4  → 1 vision
totalJoueurs 5–9  → 2 visions
totalJoueurs 10–14 → 3 visions
totalJoueurs ≥ 15 → totalJoueurs ÷ 4 visions
```
- **Initialisé dans** : `startGame()` → `visionsRestantes`
- **Appliqué dans** : `inspectPlayer()` → décrémentation + déchéance
- **Planification** : `_getNextNightPhase()` → `hasActiveSeer()` vérifie `visionsRestantes > 0`

### 2. Quota de potions scalant de la Sorcière
```
maxPotions = max(1, totalJoueurs ÷ 10)
< 20 joueurs  → 1 potion de vie + 1 potion de mort
20–29 joueurs → 2 potions de chaque
≥ 30 joueurs  → 3 potions de chaque
```
- **Initialisé dans** : `startGame()` → `potionsVie`, `potionsMort`
- **Appliqué dans** : `witchSaveVictim()`, `witchPoison()` → décrémentation + déchéance
- **Planification** : `_getNextNightPhase()` → `hasActiveWitch()` vérifie `potionsVie > 0 || potionsMort > 0`

### 3. Masquage absolu du Loup Blanc pour la Voyante
```
Si roleInspecté == GameRole.whiteWerewolf → afficher GameRole.simpleVillager
```
- **Appliqué dans** : `inspectPlayer()` — règle invariante, non modifiable
- **Utilitaire** : `getSeerPerceivedRole(GameRole actualRole)`

### 4. Garde monotone nocturne (anti-régression)
```
Si next.nightOrderIndex ≤ current.nightOrderIndex → transition annulée
```
- **Appliqué dans** : `processNightTransitions()` L.~1407

### 5. Voix double du Capitaine au vote
```
poids du vote capitaine = 2 (au lieu de 1)
```
- **Appliqué dans** : `processDayVoteResolution()` via `p.isCaptain`

---

## Historique de Migration

| Date | Action |
|---|---|
| 2026-09-18 | Intégration des 17 rôles canoniques (`ExpandedRolesState`, `ExpandedRolesCoordinator`) |
| 2026-09-18 | Port des algorithmes Kotlin → Dart (quota Voyante, quota Sorcière, masquage Loup Blanc) |
| 2026-09-18 | **Suppression du module Kotlin `engine/`** (reliquat autonome, jamais connecté à Flutter) |
| 2026-09-18 | Archivage des tests Kotlin dans `docs/engine_tests_archive/` |

---

## Module Kotlin `engine/` — Archivé

Le module Kotlin `engine/` existait comme prototype autonome (`kotlin("jvm")`).
Il n'était **jamais** connecté au runtime Flutter via Platform Channels, JNI ou FFI.
Il a été archivé dans `docs/engine_tests_archive/` puis supprimé.

Les tests Kotlin archivés servent de **spécification comportementale** de référence
et peuvent être consultés pour valider l'implémentation Dart.
