# 🐺 LUPUS ARENA — Jeu du Loup-Garou Vocal & Tactique en Temps Réel

[![Version](https://img.shields.io/badge/version-2.3.4%2B51-gold.svg)](https://github.com/Anisghd-lab/LUPUS-ARENA)
[![Flutter](https://img.shields.io/badge/Flutter-3.13%2B-blue.svg)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Realtime%20Database-orange.svg)](https://firebase.google.com)
[![Agora](https://img.shields.io/badge/Agora-RTC%20Voice-purple.svg)](https://www.agora.io)

Lupus Arena est une adaptation mobile haute performance du célèbre jeu des Loups-Garous, combinant audio spatialisé temps réel (Agora RTC Engine), synchronisation d'état atomique chiffrée (Firebase Realtime Database) et interface sombre obsidian/or gothique.

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
