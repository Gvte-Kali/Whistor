# Installer Whistor

## Préparer le serveur

Utilisez un serveur Linux avec Docker et le plugin Docker Compose v2. Debian et
Ubuntu sont des choix adaptés. Prévoyez au minimum 1 Go de RAM, 10 Go de stockage,
et davantage selon le nombre d’utilisateurs et les médias conservés.

Les commandes Docker doivent fonctionner avec votre compte. Le serveur doit
pouvoir télécharger les images et joindre le réseau Tor. Votre PC d’administration
doit pouvoir joindre le serveur par LAN, Tailscale ou SSH.

```bash
docker --version
docker compose version
git --version
```

## Déployer avec Git

Sur **le serveur** :

```bash
git clone https://github.com/Gvte-Kali/Whistor.git
cd Whistor
export WHISTOR_DIR="$PWD"
cp .env.example .env
docker compose up -d --build
```

La configuration par défaut publie l’administration sur **toutes les interfaces IPv4,
port 8080**. Vous pouvez modifier `.env` avant le démarrage pour choisir une autre
adresse ou un autre port. Voir [les modes d’accès](administration.md).

!!! tip "Commandes CLI depuis le dépôt"
    Les exemples utilisent `./whistor`. Conservez `WHISTOR_DIR` défini avec le chemin
    absolu du dépôt dans votre session. Après reconnexion SSH, revenez dans le dossier
    puis relancez `export WHISTOR_DIR="$PWD"`. Cela évite de dépendre du chemin par
    défaut de la CLI installée.

## Vérifier le premier démarrage

```bash
docker compose ps
docker compose logs --tail=50 tor synapse admin
./whistor onion
```

Tor crée l’identité `.onion` dans son volume. Synapse attend ce nom avant de générer
sa configuration et ses secrets. Ce premier démarrage peut prendre quelques minutes.
Ne supprimez pas les volumes pour accélérer ce processus.

## Créer votre administrateur

Lorsque Synapse fonctionne :

```bash
./whistor user admin monadmin
```

Saisissez le mot de passe à l’invite. Si vous avez déjà un administrateur,
utilisez ce compte plutôt que de le recréer.

Depuis **votre PC**, ouvrez `http://IP_DU_SERVEUR:8080` puis connectez-vous avec
ce compte. Le serveur Matrix est détecté automatiquement par l’interface.

[Configurer l’accès LAN ou Tailscale](administration.md){ .md-button }

## Installateur automatique

Le dépôt fournit aussi `install.sh`. Il télécharge les fichiers, construit le
service d’administration et installe la CLI si les permissions le permettent.
Pour lire le script avant exécution :

```bash
curl -fsSL https://raw.githubusercontent.com/Gvte-Kali/Whistor/main/install.sh -o install.sh
less install.sh
bash install.sh
```

Vérifiez le dossier affiché par l’installateur et définissez `WHISTOR_DIR` si votre
CLI pointe vers un autre emplacement. Pour une installation reproductible et les
mises à jour du code, la méthode Git ci-dessus est recommandée.
