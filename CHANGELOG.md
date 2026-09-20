# Changelog — Lupus Arena

Toutes les modifications notables apportées à ce projet sont documentées dans ce fichier.

## [2.5.11] - 2026-09-20

### 👁️ Petite Fille : Espionnage Audio Agora Réel, Contre-Jeu Canonique des Loups & Vignette Nocturne

#### Ajouté (Added)
- **Synchronisation Audio Agora en Temps Réel :** Coupure réelle du flux haut-parleur Agora (`_voiceService.muteSpeaker(true)`) lorsque la Petite Fille ferme les yeux pour se cacher, et réactivation instantanée (`muteSpeaker(false)`) lors de la réouverture des yeux pendant la phase des loups (`nightWerewolves`).
- **Contre-Jeu Canonique Thiercelieux des Loups-Garous :** Bouton tactique épuré « Dénicher l'espionne » (`wolf_unmask_peeker_btn`) permettant à la meute de sonder un villageois suspecté d'espionnage nocturne.
- **Mort de Frayeur Nocturne Réactive (`PETITE_FILLE_SURPRISE`) :** Si la cible des loups est la Petite Fille et qu'elle a les yeux ouverts, elle succombe immédiatement à la terreur et son décès est consigné dans les chroniques et le registre des morts ; si elle s'est cachée sous ses draps (yeux fermés), la tentative des loups échoue (fausse alerte).
- **Vignette Atmosphérique Nocturne :** Masque visuel cinématique superposé à la Table Mystique avec fentes d'observation en mode espionnage et voile protecteur sombre avec indicateur de sécurité en mode yeux fermés.
- **Traductions Intégrales 100% (FR / AR / EN) :** Intégration de toutes les clés d'interface, avertissements et causes de mort dans le dictionnaire centralisé, avec zéro emoji sur les boutons et préservation du layout LTR.

---

## [2.5.6] - 2026-09-20

### 🎨 Refonte Palette du Lobby, Ergonomie Compacte & Boutons d'Action Unifiés

#### Ajouté (Added)
- **Palette Mystique & Runique des Boutons (`LobbyActionButtons`) :** 
  - Bouton **« CRÉER UN SALON »** paré d'un dégradé vertical Mauve néon mystique (`#C040FB` vers `#5E178E`), d'une bordure luminescente (`#E28BFF`) et d'une ombre portée diffuse.
  - Bouton **« REJOINDRE »** revêtu d'un dégradé Vert électrique runique (`#64DD17` vers `#1B5E20`), d'une bordure vert menthe (`#B9F6CA`) et d'un halo runique.
  - Champ **« CODE DU SALON »** unifié au format sombre semi-transparent (`#0E1326`) avec liseré subtil violet/ardoise.
- **Top Bar Épurée & Ergonomie du Lobby :**
  - Remplacement du sélecteur par une capsule profil compacte affichant l'avatar, le pseudo du joueur et l'icône interactive d'édition rapide (suppression des libellés superflus).
  - Bouton langue compact et minimaliste à icône globe 🌐 unique (38px), sans drapeau ni texte redondant.
  - Bouton de mise à jour compact en capsule (format pill) avec badge « NEW » dynamique.
  - Empilement vertical harmonieux des 3 actions principales (`height: 50`, `width: 300`, `borderRadius: 14`) en pied d'écran.

---

## [2.5.5] - 2026-09-20

### 🦊 Rendu Visuel des Rôles, Micro-Animations, Retours Haptiques & Performance 60/120 FPS

#### Ajouté (Added)
- **Témoins Visuels des Pouvoirs Actifs & Fog of War :** Rendu asymétrique et confidentiel des capacités nocturnes sur la Table Mystique et la Grille Bento — flairage du Renard avec distinction loup/innocent (`isSniffed`, `hasWolfSmell`), bouclier du Salvateur, potions de vie/mort de la Sorcière, malédiction du Corbeau, allégeance de l'Enfant Sauvage, grognement du Montreur d'Ours et contamination de l'Épée Rouillée.
- **Micro-Animations Immersives :** Secousse d'écran amortie (`ScreenShakeWrapper`) et onde de choc d'impact pour le Chasseur, éclatement radial de flammes (`PyroFlameBurstEffect`) pour le Pyromane, halo pulsant fluide néon (`CharmedPulsingHalo`) pour le Joueur de Flûte, et entrée élastique (`AnimatedStatusBadge`) sur les badges de statut.
- **Retours Haptiques Dédiés & Régulateur Anti-Saturation :** Retours physiques tactiles distincts (`heavyImpact` pour Chasseur/Pyromane, `lightImpact` pour Flûte/sélection) et régulateur `HapticThrottler` (debounce 120ms) prévenant l'engorgement du moteur de vibration.
- **Illustration Haute Définition du Lobby :** Intégration de la nouvelle illustration d'arrière-plan immersive `backlobby.jpg` (1536x2752) pour l'écran d'accueil avec cascade de fallbacks adaptatifs.
- **Couverture de Tests :** Suite de tests unitaires complète `test/expanded_night_and_role_handlers_test.dart` (814 lignes) validant tous les rôles étendus et la préservation stricte du secret asymétrique.

#### Optimisé (Performance & Fluidité)
- **Isolation GPU (`RepaintBoundary`) :** Isolation stricte des animations continues (halo de Flûte, burst Pyromane, screen shake Chasseur), du panneau d'actions et des tuiles de joueurs garantissant 60/120 FPS sans re-rastérisation inutile.
- **Éradication de la Boucle $O(N^2)$ :** Hissage hors-boucle $O(1)$ des calculs de Fog of War et de l'utilisateur observateur dans `MysticRadialTable` et `BentoPlayerGrid`.
- **Réduction des Rebuilds & Allocations :** Algorithme de balayage arrière $O(1)$ pour le mini-ticker, sélecteur fin Riverpod `select()` pour les Chroniques du Village, et élimination du `setState` post-frame superflu lors des annonces de mort.

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
