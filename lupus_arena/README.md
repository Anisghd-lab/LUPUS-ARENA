# 🐺 LUPUS ARENA — Jeu du Loup-Garou Vocal & Tactique en Temps Réel

[![Version](https://img.shields.io/badge/version-2.3.1%2B48-gold.svg)](https://github.com/Anisghd-lab/LUPUS-ARENA)
[![Flutter](https://img.shields.io/badge/Flutter-3.13%2B-blue.svg)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Realtime%20Database-orange.svg)](https://firebase.google.com)
[![Agora](https://img.shields.io/badge/Agora-RTC%20Voice-purple.svg)](https://www.agora.io)

Lupus Arena est une adaptation mobile haute performance du célèbre jeu des Loups-Garous, combinant audio spatialisé temps réel (Agora RTC Engine), synchronisation d'état atomique chiffrée (Firebase Realtime Database) et interface sombre obsidian/or gothique.

---

## 🚀 Notes de Version — Release v2.3.1 (Build 48)

### 📌 Points Clés Modifiés :

1. **Accès Total & Direct aux Actions Stratégiques de Tous les Rôles en Mode Dev :**
   - En Mode Dev, le panneau d'actions contextuel (`BentoActionPanel`) donne désormais un accès direct et universel à toutes les actions stratégiques du rôle qui s'éveille à chaque phase nocturne et diurne (Sonde de la Voyante, Potions de la Sorcière, Protection du Salvateur, Choix de Cupidon, Chasse des Loups, Tir du Chasseur, Envoûtement de la Flûte, Huile/Feu du Pyromane, Vol du Voleur), quel que soit le rôle assigné initialement au développeur.

2. **Remplacement Global de Terminologie (God-Mode $\to$ Dev-Mode) :**
   - Remplacement exhaustif de `godMode` / `isGodMode` par `devMode` / `isDevMode` / `MODE DEV` dans tous les fichiers Dart (modèles, UI, contrôleurs, services).

3. **Parité Rigoureuse et Absolue Moteur Réel Multijoueur $\leftrightarrow$ Sandbox Dev-Mode :**
   - Exécution stricte et synchronisée du même moteur de jeu canonique (`PhaseCoordinator`, `GameNotifier`, `ServerTimeService`).
   - Mêmes règles d'arbitrage, conditions de victoire (`checkWinConditions`), résolutions des morts matinales (`resolveMorningDeaths`), gestion des amants, et quotas scalants.

4. **Harmonisation des Minuteurs & Horloge NTP (Fin des 999s) :**
   - Remplacement de tout timer artificiel par les durées canoniques harmonisées dans `GamePhase.durationSeconds` (15s / 20s / 25s / 30s / 40s / 60s).

5. **Configurateur Sandbox Dev-Mode Avancé (6 à 18 Joueurs) :**
   - Réglage interactif du nombre de participants ($N \in [6, 18]$) avec génération automatique de rôles équilibrés ou composition manuelle sur-mesure.

6. **Traductions & Intégrité Multilingue :**
   - 100% de parité sur 463 clés linguistiques (Français, Arabe, Anglais) avec layout LTR préservé pour l'arabe (`verify_translations.py` validé avec 0 erreur).

---

## 🛠️ Stack Technique

- **Framework :** Flutter (Dart 3.x)
- **State Management :** Riverpod (`StateNotifierProvider`)
- **Base de Données & Synchronisation :** Firebase Realtime Database
- **Audio & Microphones :** Agora RTC Engine
- **Sécurité :** Chiffrement HMAC-SHA256 pour les cartes secrètes
