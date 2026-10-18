# Steal an Anomaly (nom provisoire)

Jeu Roblox tycoon / collection / vol entre joueurs, thème horreur légère.
Chaque joueur possède un hôtel, repère les anomalies déguisées en clients,
les capture, et elles lui rapportent de l'argent. Les autres joueurs peuvent
venir les voler.

## Structure

```
src/
  server/            logique autoritaire (Scripts)
    Main.server.luau charge les services
    Services/        un fichier par service
    Util/            outils serveur (RateLimiter...)
  client/            interface et contrôles (LocalScripts)
    Main.client.luau charge les contrôleurs
    Controllers/     un fichier par contrôleur
  shared/            modules partagés serveur + client
    Config/          TOUS les chiffres d'équilibrage (modifiables sans toucher au code)
    Types.luau       types partagés
    Remotes.luau     liste centralisée des RemoteEvents
```

Dans Studio, Rojo place `src/shared` dans `ReplicatedStorage > Shared`,
`src/server` dans `ServerScriptService > Server` et `src/client` dans
`StarterPlayer > StarterPlayerScripts > Client`.

---

## Installation (à faire une seule fois)

### 1. GitHub Desktop (pour récupérer le code)

1. Télécharge et installe **GitHub Desktop** : https://desktop.github.com
2. Ouvre-le et connecte-toi avec ton compte GitHub.
3. Menu **File > Clone repository**, choisis ce dépôt, clique **Clone**.
4. Note le dossier où il a été copié (champ « Local path »).

À chaque fois que je publie une nouvelle étape : dans GitHub Desktop, clique
**Fetch origin** puis **Pull origin**.

### 2. Rokit (installe Rojo et Wally pour toi)

**Windows**
1. Va sur https://github.com/rojo-rbx/rokit/releases/latest
2. Télécharge le fichier qui finit par `windows-x86_64.zip`.
3. Fais un clic droit sur le zip > **Extraire tout**.
4. Double-clique sur `rokit.exe`. Une fenêtre s'ouvre et l'installe, puis se ferme.

**Mac**
1. Ouvre l'app **Terminal** (Cmd + Espace, tape « Terminal », Entrée).
2. Colle cette ligne puis Entrée :
   ```
   curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
   ```
3. Ferme le Terminal et rouvre-le.

### 3. Rojo et Wally

1. Dans GitHub Desktop : menu **Repository > Open in Command Prompt** (Windows)
   ou **Open in Terminal** (Mac). Un terminal s'ouvre déjà dans le bon dossier.
2. Tape `rokit install` puis Entrée. S'il demande de faire confiance à un outil
   (« trust »), réponds `y`.
3. Tape `rojo plugin install` puis Entrée. Ça installe le plugin Rojo dans Studio.
4. Vérifie : `rojo --version` doit afficher `Rojo 7.7.1`.

---

## Travailler au quotidien

1. Ouvre **Roblox Studio** > **New** > **Baseplate**.
2. Dans le terminal ouvert dans le dossier du projet : `rojo serve`
   (laisse cette fenêtre ouverte tant que tu travailles).
3. Dans Studio : onglet **Plugins** > **Rojo** > bouton **Connect**.
   Le code apparaît dans l'Explorer (ServerScriptService > Server, etc.).
4. Ouvre la fenêtre de sortie : onglet **View** > **Output**.
5. Clique **Play**.

Pour sauvegarder ta place Studio (carte, réglages) : **File > Save to Roblox**.
Le code, lui, vit dans ce dossier ; Rojo le renvoie dans Studio à chaque connexion.
