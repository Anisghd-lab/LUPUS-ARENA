# 🐺 LUPUS ARENA — Jeu du Loup-Garou Vocal & Tactique en Temps Réel

[![Version](https://img.shields.io/badge/version-2.3.2%2B49-gold.svg)](https://github.com/Anisghd-lab/LUPUS-ARENA)
[![Flutter](https://img.shields.io/badge/Flutter-3.13%2B-blue.svg)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Realtime%20Database-orange.svg)](https://firebase.google.com)
[![Agora](https://img.shields.io/badge/Agora-RTC%20Voice-purple.svg)](https://www.agora.io)

Lupus Arena est une adaptation mobile haute performance du célèbre jeu des Loups-Garous, combinant audio spatialisé temps réel (Agora RTC Engine), synchronisation d'état atomique chiffrée (Firebase Realtime Database) et interface sombre obsidian/or gothique.

---

## 🚀 Notes de Version — Release v2.3.2 (Build 49)

### 📌 Points Clés Modifiés :

1. **Intégration Complète de Toutes les Cartes & Rôles dans le Configurateur Dev-Mode :**
   - Disponibilité intégrale des 31 cartes/rôles du jeu dans le panneau de composition de la salle Sandbox Dev-Mode (6 à 18 joueurs) :
     - *Meute des Loups :* Loup-Garou, Grand Méchant Loup, Loup Blanc, Loup Noir, Infect Père des Loups, Chiot Loup.
     - *Villageois à Pouvoirs :* Voyante, Sorcière, Chasseur, Salvateur, Cupidon, Petite Fille, Voleur, Ancien, Bouc Émissaire, Idiot du Village, Deux Sœurs, Trois Frères, Renard, Montreur d'Ours, Juge Bègue, Chevalier à l'Épée Rouillée, Servante Dévouée, Comédien.
     - *Rôles Spéciaux & Solitaires :* Enfant Sauvage, Pyromane, Corbeau, Ange, Joueur de Flûte, Abominable Sectaire, Voleur d'Âmes.
     - *Villageois Simple.*

2. **Isolation Vocale Hermétique & Zéro Accès Micro pour les Bots :**
   - Les bots passifs (`player.isBot`) et les identifiants Agora non assignés (`agoraUid <= 0`) sont rigoureusement exclus de tout halo de prise de parole, d'état vocal actif ou de canal Agora. Seul le micro du joueur réel est sollicité lors de ses tours de parole légitimes.

3. **Accès Total & Direct aux Actions Stratégiques en Mode Dev :**
   - Déblocage contextuel universel de toutes les actions nocturnes et diurnes dans `BentoActionPanel` pour le développeur.

4. **Traductions & Intégrité Multilingue :**
   - 100% de parité sur 463 clés linguistiques (Français, Arabe, Anglais) avec layout LTR préservé pour l'arabe (`verify_translations.py` validé avec 0 erreur).

---

## 🛠️ Stack Technique

- **Framework :** Flutter (Dart 3.x)
- **State Management :** Riverpod (`StateNotifierProvider`)
- **Base de Données & Synchronisation :** Firebase Realtime Database
- **Audio & Microphones :** Agora RTC Engine
- **Sécurité :** Chiffrement HMAC-SHA256 pour les cartes secrètes
