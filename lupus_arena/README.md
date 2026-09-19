# 🐺 LUPUS ARENA — Jeu du Loup-Garou Vocal & Tactique en Temps Réel

[![Version](https://img.shields.io/badge/version-2.3.0%2B47-gold.svg)](https://github.com/Anisghd-lab/LUPUS-ARENA)
[![Flutter](https://img.shields.io/badge/Flutter-3.13%2B-blue.svg)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Realtime%20Database-orange.svg)](https://firebase.google.com)
[![Agora](https://img.shields.io/badge/Agora-RTC%20Voice-purple.svg)](https://www.agora.io)

Lupus Arena est une adaptation mobile haute performance du célèbre jeu des Loups-Garous, combinant audio spatialisé temps réel (Agora RTC Engine), synchronisation d'état atomique chiffrée (Firebase Realtime Database) et interface sombre obsidian/or gothique.

---

## 🚀 Notes de Version — Release v2.3.0 (Build 47)

### 📌 Points Clés Modifiés :

1. **Remplacement Global de Terminologie (God-Mode $\to$ Dev-Mode) :**
   - Migration intégrale de toutes les occurrences de `godMode` / `isGodMode` / `god_mode` vers `devMode` / `isDevMode` / `MODE DEV` dans l'ensemble des contrôleurs, modèles, dispatchers et composants d'interface.
   - Libellés officiels harmonisés sur « Mode Dev » / « Dev-Mode ».

2. **Parité Rigoureuse et Absolue Moteur Réel Multijoueur $\leftrightarrow$ Sandbox Dev-Mode :**
   - Exécution stricte et synchronisée du même moteur de jeu canonique (`PhaseCoordinator`, `GameNotifier`, `ServerTimeService`).
   - Mêmes règles d'arbitrage, conditions de victoire (`checkWinConditions`), résolutions des morts matinales (`resolveMorningDeaths`), gestion des amants, et quotas scalants ($\max(1, \lfloor N/4 \rfloor)$ pour la Voyante et $\max(1, \lfloor N/10 \rfloor)$ pour la Sorcière).
   - Même schéma Firebase RTDB avec chiffrement cryptographique SHA-256 / HMAC des jetons secrets de rôles (`secret_roles`) et de la meute (`wolf_pack`).

3. **Harmonisation des Minuteurs & Horloge NTP (Fin des 999s) :**
   - Remplacement de tout timer artificiel ou infini par les durées authentiques de production harmonisées dans `GamePhase.durationSeconds` (15s / 20s / 25s / 30s / 40s / 60s).
   - Synchronisation absolue via l'horloge estimée NTP (`ServerTimeService`, `phaseStartedAt`, `phaseEndsAt`).

4. **Configurateur Sandbox Dev-Mode Avancé (6 à 18 Joueurs) :**
   - Réglage interactif du nombre de participants ($N \in [6, 18]$) avec génération automatique de rôles équilibrés ou composition manuelle sur-mesure.
   - Intégration de bots passifs réactifs dotés de jetons cryptographiques individuels.

5. **Système d'Incarnation Dynamique (`effectiveUserId`) :**
   - Sélecteur horizontal d'incarnation permettant au développeur d'endosser le rôle de n'importe quel joueur/bot pour exécuter ses actions réelles de nuit et de jour (vote des loups, potion de sorcière, vision de voyante, protection du salvateur, tir du chasseur, flûte, pyromane) en respectant les contraintes authentiques du jeu.

6. **Épuration de l'Interface Dev :**
   - Suppression du bouton redondant « Créer un salon multijoueur » dans la modale Dev pour se concentrer exclusivement sur la « Salle Dev-Mode (Sandbox) ».

7. **Traductions & Intégrité Multilingue :**
   - 100% de parité sur 463 clés linguistiques (Français, Arabe, Anglais) avec layout LTR préservé pour l'arabe (`verify_translations.py` validé avec 0 erreur).

---

## 🛠️ Stack Technique

- **Framework :** Flutter (Dart 3.x)
- **State Management :** Riverpod (`StateNotifierProvider`)
- **Base de Données & Synchronisation :** Firebase Realtime Database
- **Audio & Microphones :** Agora RTC Engine
- **Sécurité :** Chiffrement HMAC-SHA256 pour les cartes secrètes
