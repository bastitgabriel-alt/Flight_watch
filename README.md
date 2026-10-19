# Steal an Anomaly (nom provisoire)

Jeu Roblox tycoon / collection / vol entre joueurs, thème horreur légère.
Chaque joueur possède un hôtel. Des clients arrivent à la réception, certains
sont des anomalies déguisées : il faut les repérer et les capturer. Elles
rapportent de l'argent chaque seconde dans leurs cellules.

## Où en est le jeu

| Étape | État |
|---|---|
| 1. Projet de base | ✅ |
| 2. Sauvegarde des données (ProfileStore) | ✅ à tester dans Studio |
| 3. Carte placeholder + attribution des hôtels | ✅ à tester dans Studio |
| 4. Réception : clients, indices, capture | ✅ à tester dans Studio |
| 5. Cellules + revenu passif + argent animé | ✅ à tester dans Studio |
| 6. Boutique : cellules, lampe UV, scanner thermique, sécurité | ✅ à tester dans Studio |
| 7. Vol entre joueurs + verrou de porte | ✅ à tester dans Studio |
| 8. Catalogue des anomalies + classements | ✅ à tester dans Studio |
| 9. Monétisation (2 gamepasses, 2 produits Robux) | ✅ code prêt, IDs à créer (voir plus bas) |
| 10. Tutoriel (3 étapes), sons, interface mobile, statistiques | ✅ à tester dans Studio |
| 11. Revue multijoueur (serveur plein, hôtels, vols) | ✅ |
| 12. Publication | 📋 suis [PUBLICATION.md](PUBLICATION.md) |

---

## Tester le jeu (Mac)

### Une seule fois : installer Roblox Studio
1. Va sur https://create.roblox.com et connecte-toi (crée un compte Roblox si besoin, c'est gratuit).
2. Clique **Start Creating** : ça télécharge Roblox Studio. Installe-le comme une app normale.

### À chaque nouvelle version
1. Sur GitHub, ouvre le dossier **build** de ce dépôt, puis le fichier **StealAnAnomaly.rbxlx**.
2. Clique le bouton **Download raw file** (flèche vers le bas, en haut à droite du fichier).
3. Ouvre Roblox Studio > menu **File > Open from File...** > choisis le fichier téléchargé.
4. Ouvre la fenêtre de sortie : onglet **View** (ou **Window**) > **Output**.
5. Clique **Play** (bouton ▶).

### Ce que tu dois voir
- Dans **Output** : `[Serveur] Serveur prêt` puis `[Client] Client prêt`.
  Des messages jaunes de ProfileStore disant que les données ne sont pas sauvegardées
  sont **normaux** dans un fichier local (voir plus bas).
- Une place centrale et 6 hôtels. Tu es téléporté derrière le comptoir de ton hôtel,
  ton nom s'affiche sur l'enseigne.
- En haut : ton argent et ton revenu par seconde.
- Des clients arrivent au comptoir. Approche-toi et appuie sur **E** (ou touche le bouton
  sur téléphone) pour **Recevoir**. Compare :
  - le **registre** : son nom y est-il, bien écrit ?
  - la **photo** de sa carte d'identité : est-ce la même personne ?
  - son **ombre** au sol ;
  - ses **yeux**.
- **Donner la clé** à un vrai client = pourboire. **Capturer** une anomalie = elle va dans une
  cellule et rapporte de l'argent chaque seconde. Les erreurs coûtent cher !

### Commandes de test (tape-les dans le chat pendant le Play)
| Commande | Effet |
|---|---|
| `!argent 1000` | +1000 $ |
| `!anomalie TheOwner Neon` | ajoute une anomalie (mutation optionnelle : `Golden`, `Neon`) |
| `!prochain anomalie` | le prochain client sera une anomalie |
| `!prochain normal` | le prochain client sera un vrai client |
| `!prochain MidnightBride` | le prochain client sera cette anomalie précise |
| `!pass DoubleMoney` | simule le gamepass Argent x2 (ou `ExtraCells` : +3 cellules) |
| `!chance` | lance une « Nuit chanceuse » (raretés x3 pendant 10 min) |
| `!temps 10` | accélère le temps x10 (revenus et clients) ; `!temps 1` pour revenir |
| `!event BloodMoon` | lance un événement (`BloodMoon`, `Blackout`, `GhostRush`) ; `!event stop` pour l'arrêter |
| `!renaissance` | renaissance gratuite (pour tester) |
| `!tuto` | relance le tutoriel |
| `!reset` | remet tes données à zéro |

Ids des anomalies : `Doppelganger`, `Shadowless`, `MrsSmile`, `GreyTraveler`, `Sleepwalker`,
`MirrorLady`, `ForgottenMailman`, `InvertedGuest`, `PhantomConcierge`, `MidnightBride`,
`FacelessWarden`, `TheOwner`.

### Tester à plusieurs (vol et verrou)
Onglet **Test** > zone **Clients and Servers** > choisis **2 Players** > **Start**.
Deux fenêtres de jeu s'ouvrent, chacune avec son hôtel. Dans la fenêtre du joueur 2,
entre dans l'hôtel du joueur 1, maintiens **E** devant une anomalie (« Voler ») et
ramène-la chez toi. Le joueur 1 peut la récupérer en touchant le voleur (« Récupérer »),
ou fermer sa porte avec le bouton **Verrouiller**.

### Sauvegarde réelle
Dans un fichier local, la sauvegarde est simulée (tout repart de zéro à chaque Play).
Pour tester la vraie sauvegarde : **File > Publish to Roblox**, puis **Home > Game Settings >
Security** > active **Enable Studio Access to API Services** > **Save**.

### Sons (à faire une fois)

Les sons du jeu sont dans `build/SonsEtImages.zip` (dossier `sounds`). Roblox
ne permet pas de les mettre directement dans le fichier du jeu : il faut les
importer sur Roblox, puis coller leurs numéros dans
`src/shared/Config/SoundConfig.luau` (ou les envoyer à Claude).

### Monétisation (à faire une fois le jeu publié)
Les achats Robux sont prêts mais cachés tant qu'ils n'ont pas d'Id. Pour les créer :
1. Publie le jeu : **File > Publish to Roblox** (choisis un nom, laisse-le privé pour l'instant).
2. Va sur https://create.roblox.com/dashboard/creations > clique ton jeu.
3. Menu de gauche **Monetization > Passes** > **Create a Pass** : crée « Argent x2 » puis
   « +3 cellules » (image, nom, puis active **Item for Sale** et choisis un prix).
4. Menu **Monetization > Developer Products** > **Create** : crée « Sac d'argent » et
   « Nuit chanceuse » avec un prix.
5. Chaque pass / produit a un **ID** (un long numéro, bouton « Copy Asset ID »).
   Envoie-moi les 4 numéros : je les mets dans le jeu.

Prix conseillés pour démarrer : Argent x2 = 199 R$, +3 cellules = 149 R$,
Sac d'argent = 49 R$, Nuit chanceuse = 79 R$.

### Si quelque chose ne marche pas
Copie les lignes **rouges** de la fenêtre Output et colle-les-moi.

---

## Pour les curieux : organisation du code

```
src/
  server/               logique du jeu, côté serveur (le serveur décide de tout)
    Main.server.luau    démarre tous les services
    Services/           PlayerData, Hotel, Guest, Anomaly, Income, Debug
    Modules/            génération des clients, carte, calculs, schéma des données
    Vendor/             ProfileStore (sauvegarde)
  client/               interface du joueur
    Controllers/        Hud (argent), Reception, Prompt
  shared/
    Config/             TOUS les chiffres d'équilibrage, modifiables sans toucher au reste
    Types.luau, Remotes.luau, Util/
tests/run.luau          tests de la logique et de la géométrie de la carte (hors Roblox)
build/                  fichier de jeu prêt à ouvrir dans Studio
```

Le fichier `build/StealAnAnomaly.rbxlx` est généré à partir de `src/` avec
[Rojo](https://rojo.space) (`rojo build -o build/StealAnAnomaly.rbxlx`).
