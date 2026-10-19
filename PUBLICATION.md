# Publier le jeu : checklist (étape 12)

Fais ces étapes dans l'ordre. Compte environ 30 minutes.

## 1. Publier la place
1. Ouvre le dernier `build/StealAnAnomaly.rbxlx` dans Roblox Studio.
2. **File > Publish to Roblox** > **Create a new experience**.
3. Nom : `Steal an Anomaly` (ou ton nom définitif). Genre : **Simulation**.
4. Laisse l'accès en **privé** pour l'instant.

## 2. Réglages du jeu (Studio > Home > Game Settings)
- **Basic Info** :
  - Description : copie le texte de la section 5 ci-dessous.
  - Appareils : coche **Phone, Tablet, Computer** (et Console si tu veux).
- **Permissions** : Playability = **Private** tant que tu testes.
- **Security** : active **Enable Studio Access to API Services**
  (pour tester la vraie sauvegarde dans Studio).
- **Places > (ta place) > Configure** : **Max Players = 6**
  (une place par hôtel ; au-delà, le joueur en trop est renvoyé).
- **Avatar** : Avatar type **R15**.
- Clique **Save**.

## 3. Achats Robux (Creator Hub)
Sur https://create.roblox.com/dashboard/creations > ton jeu > **Monetization** :
- **Passes** : « Argent x2 » (199 R$ conseillé) et « +3 cellules » (149 R$).
- **Developer Products** : « Sac d'argent » (49 R$) et « Nuit chanceuse » (79 R$).
- Envoie-moi les **4 IDs** : je les mets dans le jeu et je te renvoie le fichier.
  Republie ensuite (**File > Publish to Roblox**).

## 4. Ton UserId (commandes admin)
Envoie-moi le nombre qui apparaît dans l'adresse de ta page de profil Roblox
(`roblox.com/users/123456/profile`). Je l'ajoute à `GameConfig.AdminUserIds`
pour que tu puisses utiliser les commandes `!` dans le vrai jeu (et personne d'autre).

## 5. Page du jeu
**Description** (à coller) :
> 🏨 Tu tiens un hôtel… mais certains clients ne sont pas humains.
> Inspecte chaque client : son nom est-il dans le registre ? Sa photo lui
> ressemble-t-elle ? A-t-il une ombre ? Ses yeux brillent-ils ?
> 🪤 Capture les anomalies, enferme-les dans tes cellules : elles te rapportent
> de l'argent chaque seconde !
> 🕵️ Vole les anomalies des autres joueurs… et verrouille ta porte avant qu'ils
> ne volent les tiennes.
> 📖 Découvre les 12 anomalies, des Communes aux Mythiques.

- **Icône** : image carrée 512×512 (exemple : un œil rouge derrière un comptoir d'hôtel).
- **Miniatures** : 3 captures d'écran en 1920×1080 : la réception avec un client,
  des cellules pleines d'anomalies, un vol en cours.
  Dans Studio, cache l'interface (bouton « UI » en haut) avant de capturer.

## 5 bis. Icône et miniatures

Dans `build/SonsEtImages.zip`, dossier `images` :
- `Icon.png` (512 x 512) : l'icône du jeu
- `Thumbnail1_Reception.png`, `Thumbnail2_Vol.png`, `Thumbnail3_Collection.png` (1920 x 1080) : les images de la page du jeu

Sur create.roblox.com : Créations > ton jeu, puis dans le menu de gauche
(partie « Configurer ») cherche « Icône » et « Miniatures », et importe les fichiers.

## 6. Questionnaire de maturité (obligatoire)
Creator Hub > ton jeu > **Audience > Maturity & Compliance** > remplis le questionnaire.
Réponses pour ce jeu :
- Violence : **aucune** (on capture, on ne blesse pas ; pas de sang).
- Peur : **légère** (thème « horreur légère », flash rouge court, pas de gore).
- Pas de jeu d'argent, pas de contenu romantique, pas de langage grossier.
- Chat : texte standard de Roblox.

## 7. Dernier test avant le public
1. Avec 2 ou 3 amis (ou **Test > Server & Clients > 3 joueurs** dans Studio) :
   tutoriel, réception, boutique, vol, verrou, catalogue, classement.
2. Vérifie la vraie sauvegarde : joue, quitte, reviens, ton argent doit être là.
3. Fais un achat test de chaque produit (Studio fait des achats gratuits en test).

## 8. Ouvrir au public
Game Settings > **Permissions** > Playability = **Public** > **Save**.
Partage le lien et regarde les statistiques dans **Analytics** sur le Creator Hub :
tutoriel terminé, première capture, premier achat, premier vol, durée des sessions.
