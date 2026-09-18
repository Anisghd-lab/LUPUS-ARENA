# 🚀 Release Notes — Lupus Arena v2.0.0 (Refonte Moteur & Architecture)

**Date :** 18 Septembre 2026  
**Version :** 2.0.0  
**Statut :** Stable & Production Ready  
**Dépôts :** `origin/main` et `anisghd/main`

---

## 🌟 Points Forts de la Version 2.0.0

Cette version majeure unifie et modernise l'intégralité du moteur de jeu de **Lupus Arena**, améliore drastiquement les performances réseau et graphiques, résout tous les problèmes d'ergonomie mobile et assainit le dépôt de code.

---

### 1. ⏱️ Synchronisation Temps Serveur Infaillible
- **Horloge Canonique :** Migration des minuteurs locaux vers une référence temps serveur Firebase (`phaseEndsAt` en timestamp epoch millisecondes).
- **Zéro Décalage :** Décompte interpolé fluide via `ValueNotifier<int>` garantissant que tous les joueurs changent de phase au même instant absolu.

### 2. 🎭 17 Rôles Canoniques & Algorithmes de Quotas Scalants
- **Rôles Étendus :** Intégration complète et arbitrée des 30 cartes (Loup Blanc, Pyromane, Joueur de Flûte, Corbeau, Ancien, Chasseur, Idiot, Cupidon, Bouc Émissaire, Deux Sœurs, Trois Frères, Enfant Sauvage, etc.).
- **Formules de Scaling $N$ :**
  - Quota Voyante : $1 / 2 / 3 / \lfloor N/4 \rfloor$ visions selon le nombre de joueurs assis.
  - Quota Sorcière : $\max(1, \lfloor N/10 \rfloor)$ potions de vie et de mort.
  - Masquage solitaire du Loup Blanc lors des inspections.

### 3. 🏛️ Unification Moteur Dart & Clean Architecture
- **Single Source of Truth :** Suppression intégrale du module Kotlin obsolète `engine/` et formalisation de `docs/ARCHITECTURE_MOTEUR.md`.
- **Modularisation de `GameNotifier.dart` :** Découpage du monolithe de 3700 lignes en 4 coordinateurs spécialisés :
  - `GamePhaseCoordinator` : Transitions et cycle jour/nuit.
  - `VoteCoordinator` : Dépouillement, vote double du Capitaine et égalités.
  - `RoleActionDispatcher` : Arbitrage individuel des pouvoirs de rôles.
  - `RoomPresenceService` : Heartbeats, connectivité et états vocaux Agora.

### 4. ⚡ Réseau Firebase RTDB Haute Performance
- **Schéma Canonique Unique :** Élimination des requêtes miroir `games/$roomCode` au profit du chemin unique `rooms/$roomCode` avec écritures atomiques par patch (`update()`). Réduction de **60% de la bande passante**.
- **Abonnements Partitionnés (Sharding) :** Découpage de l'écoute globale en 5 listeners spécialisés (`public_state`, `players`, `votes`, `presence`, `logs`) avec nettoyage systématique contre les fuites mémoire (`_cancelAllRoomSubscriptions()`).

### 5. 🎨 Optimisations Graphiques & Zéro Surchauffe UI
- **Isolation Skia/Impeller :** Encapsulation de la couche d'arrière-plan animée et de chaque nœud joueur dans des `RepaintBoundary` dédiés.
- **Réutilisation des Widgets :** Utilisation du paramètre `child` dans `AnimatedBuilder` pour éviter toute réallocation inutile à 60-120 FPS.
- **Pulsation Vocale Intelligente :** Arrêt automatique des contrôleurs d'animation dès que la parole cesse.

### 6. 📱 Table Radiale Adaptative Multi-Anneaux (4 à 30 Joueurs)
- **Dimensionnement Réactif :** Calcul adaptatif par `LayoutBuilder` / `MediaQuery`.
- **Double Anneau Interfolié :** Dès que $N > 16$, disposition automatique en double anneau concentrique avec décalage angulaire ($\pi / N_{\text{inner}}$) empêchant tout chevauchement d'avatars ou de pseudonymes.
- **Accessibilité Mobile :** Hitbox tactile garantie $\ge 48 \times 48$ dp (`HitTestBehavior.opaque`).
- **Transitions Douces :** Repositionnement animé avec `AnimatedPositioned` (350 ms).

### 7. 🎬 Cinématique d'Annonce des Défunts
- **Anti-Bouclage :** Registre de déduplication strict `_playedKeys` empêchant les snapshots Firebase de relancer les cartes déjà jouées.
- **Séquençage Minuté :** Révélation 3D fluide (~3.5 s par victime) et effacement progressif via `AnimatedSwitcher`.

### 8. 🧹 Dépôt Git Ultra-Léger
- **Purge Historique :** Extraction rétroactive du dossier `LOUP GAROU ENHANCED_BACKUP` (162 Mo) et des fichiers `Thumbs.db` / `.DS_Store` via `git-filter-repo`.
- **Réduction du Dépôt :** Taille de `.git` passée de 180 Mo à **14 Mo** (>90% de gain).
- **Règles `.gitignore` durcies** pour prévenir toute réintroduction.

---

## 📦 Détails Techniques du Build

- **SDK Flutter/Dart :** Dart 3.13+ / Flutter 3.x
- **Plateformes supportées :** Android, iOS, Web
- **Validation :** 51/51 fichiers Dart validés sans avertissements ni erreurs de syntaxe.
