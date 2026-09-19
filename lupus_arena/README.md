# 🐺 LUPUS ARENA — Jeu du Loup-Garou Vocal & Tactique en Temps Réel

[![Version](https://img.shields.io/badge/version-2.3.3%2B50-gold.svg)](https://github.com/Anisghd-lab/LUPUS-ARENA)
[![Flutter](https://img.shields.io/badge/Flutter-3.13%2B-blue.svg)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Realtime%20Database-orange.svg)](https://firebase.google.com)
[![Agora](https://img.shields.io/badge/Agora-RTC%20Voice-purple.svg)](https://www.agora.io)

Lupus Arena est une adaptation mobile haute performance du célèbre jeu des Loups-Garous, combinant audio spatialisé temps réel (Agora RTC Engine), synchronisation d'état atomique chiffrée (Firebase Realtime Database) et interface sombre obsidian/or gothique.

---

## 🚀 Notes de Version — Release v2.3.3 (Build 50)

### 📌 Points Clés Modifiés :

1. **Exclusion Stricte de la Carte « Capitaine / Maire » des Sélecteurs de Rôles (Multijoueur & Sandbox Dev-Mode) :**
   - Conformément aux règles canoniques, le rôle de Maire/Capitaine est un statut honorifique et électif décerné par vote du village (`mayorElection` / `captainElection`) et non une carte distribuée au deck de départ.
   - La carte du Maire est désormais formellement exclue des sélecteurs de deck multijoueur (`RoleSelectorBento`), de la distribution aléatoire et des modales Dev-Mode d'attribution forcée de rôle.

2. **Simulation de Prise de Parole des Bots & Étanchéité Micro :**
   - Les bots (`player.isBot`) participent au cycle visuel du jeu : le halo de prise de parole et l'action de fin de tour ("Passer la parole" / timer) sont activés lors de leur tour. En revanche, ils restent rigoureusement exclus de tout flux Agora/RTC. Le microphone du joueur réel demeure strictement coupé et n'est sollicité que lors de son tour légitime.

3. **Intégration Complète des 31 Cartes Jouables dans le Configurateur Dev-Mode Sandbox :**
   - Disponibilité intégrale des 31 rôles de jeu dans le panneau de composition de la salle Sandbox Dev-Mode (6 à 18 joueurs).

4. **Accès Total aux Actions Stratégiques en Mode Dev & Intégrité Multilingue :**
   - Déblocage universel des actions de rôle dans `BentoActionPanel` en Dev-Mode.
   - 100% de parité sur 463 clés linguistiques (Français, Arabe, Anglais) avec layout LTR préservé pour l'arabe (`verify_translations.py` validé avec 0 erreur).

---

## 🛠️ Stack Technique

- **Framework :** Flutter (Dart 3.x)
- **State Management :** Riverpod (`StateNotifierProvider`)
- **Base de Données & Synchronisation :** Firebase Realtime Database
- **Audio & Microphones :** Agora RTC Engine
- **Sécurité :** Chiffrement HMAC-SHA256 pour les cartes secrètes
