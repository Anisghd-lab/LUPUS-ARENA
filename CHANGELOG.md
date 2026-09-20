# Changelog — Lupus Arena

Toutes les modifications notables apportées à ce projet sont documentées dans ce fichier.

---

## [2.5.4] - 2026-09-20

### 🛡️ Stabilisation Multijoueur, Sécurité Firebase & Revanche Atomique

#### Corrigé (Fixed)
- **Failover & Déconnexion d'Hôte (LA-003) :** Surveillance active de la présence de l'hôte (`_hostPresenceSubscription`), élection déterministe et reprise immédiate des minuteurs serveur sans gel de partie.
- **Revanche / Rematch Atomique (LA-004) :** Élimination de la race condition lors du clic simultané sur "Rejouer", quorum exclusif à l'Hôte avec verrou mutex anti-double reset, et correction des chemins de redistribution des rôles secrets (`rooms/$roomCode/secret_roles`).
- **Règles de Sécurité & Validation Serveur Firebase RTDB (LA-005) :** Déploiement des règles `.validate` serveur interdisant les rollbacks de tours, verrouillant le cimetière (anti-résurrection) et interdisant les votes aux défunts.
- **Dépouillement Autoritaire & Consensus de Meute (LA-007) :** Dépouillement diurne et élection du Maire basés sur une lecture directe autoritaire Firebase (`votes.get()`), et calcul de consensus majoritaire pour la chasse nocturne des loups.
- **Réinitialisation Systémique & Synchronisation Atomique :** Purge systématique et atomique de tous les votes, sélections de cibles et visions de voyante à chaque transition de phase ou de cycle nocturne.

---

## [2.0.0] - 2026-09-18

### 🌟 Refonte Moteur, Optimisations Graphiques & Hygiène Git

#### Ajouté (Added)
- **Minuteur Serveur Canonique :** Synchronisation absolue de fin de phase (`phaseEndsAt`) calculée par le serveur Firebase.
- **Rôles & Quotas Scalants :** Intégration complète des 17 rôles manquants avec formules de scaling dépendantes de l'effectif total $N$.
- **Clean Architecture Modulaire :** Coordinateurs dédiés `GamePhaseCoordinator`, `VoteCoordinator`, `RoleActionDispatcher`, `RoomPresenceService`.
- **Table Radiale Adaptative :** Double anneau concentrique avec interfoliage angulaire ($\pi / N_{\text{inner}}$) pour les salons de 16 à 30 joueurs.
- **Hitbox Accessibilité :** Zones tactiles minimales de $48 \times 48$ dp pour chaque joueur.
- **Animations de Repositionnement :** Transitions `AnimatedPositioned` fluides lors des changements de disposition.
- **Séquençage Cinématique 3D des Défunts :** Déduplication stricte `_playedKeys` et transition `AnimatedSwitcher`.
- **Documentation :** Création de `docs/ARCHITECTURE_MOTEUR.md` et `docs/RELEASE_NOTES_v2.0.0.md`.

#### Optimisé (Changed / Performance)
- **Sharding Firebase RTDB :** Remplacement de l'écoute monolithique par 5 abonnements partitionnés (`public_state`, `players`, `votes`, `presence`, `logs`).
- **Écritures Réseau Atomiques :** Unification sous `rooms/$roomCode` et suppression des écritures miroir redondantes (-60% de trafic réseau).
- **Isolation Skia/Impeller :** Frontières de rendu `RepaintBoundary` et réutilisation de `child` dans `AnimatedBuilder` éliminant les repaints 60-120 FPS sur l'arbre complet.
- **Gestion Énergie / Batterie :** Arrêt automatique du contrôleur de pulsation audio lorsqu'aucun joueur ne parle.

#### Supprimé / Nettoyé (Removed)
- **Module Kotlin `engine/` :** Suppression définitive, Dart devenant l'unique source de vérité.
- **Purge Historique Git :** Élimination définitive de `LOUP GAROU ENHANCED_BACKUP` (162 Mo) et fichiers `Thumbs.db`/`.DS_Store` via `git-filter-repo` (taille de `.git` réduite de 180 Mo à 14 Mo).
