# Mises à jour et sauvegardes

## Comprendre `latest`

Synapse utilise `ghcr.io/element-hq/synapse:latest`. L’administration est construite
à partir de Ketesa `latest` et Nginx `stable-alpine`. Les versions changent avec le
temps ; une mise à jour peut inclure une migration de la base de données.

Avant toute mise à jour, consultez les
[notes de migration Synapse](https://element-hq.github.io/synapse/latest/upgrade.html),
y compris celles des versions intermédiaires sautées.

## Sauvegarder

Les éléments critiques sont :

| Élément | Pourquoi le conserver |
| --- | --- |
| Volume `tor-data` | Clés privées et identité `.onion` |
| Volume `synapse-data` | Base de données, configuration, médias et clé de signature |
| `.env` et fichiers du déploiement | Paramètres réseau et configuration reproductible |

Les volumes portent normalement le préfixe du projet Compose. Vérifiez leurs noms
avec `docker volume ls` : ne supposez pas qu’ils commencent toujours par `whistor_`.

Pour une sauvegarde cohérente de SQLite, arrêtez les services qui écrivent avant
l’archivage. Depuis le dossier du déploiement, sur le serveur :

```bash
mkdir -p backups
docker compose stop synapse tor admin
docker compose run --rm --no-deps --user 0 --entrypoint /bin/sh \
  -v "$PWD/backups:/backup" synapse \
  -c 'tar -czf /backup/whistor-data.tar.gz -C /data .'
docker compose run --rm --no-deps --user 0 --entrypoint /bin/sh \
  -v "$PWD/backups:/backup" tor \
  -c 'tar -czf /backup/whistor-tor.tar.gz -C /var/lib/tor/hidden_service .'
docker compose up -d
```

Ces commandes remplacent les deux fichiers d’archive s’ils existent déjà. Déplacez
chaque sauvegarde dans un dossier daté avant d’en refaire une. Copiez également
`.env` et conservez le commit utilisé (`git rev-parse HEAD`) et les références des
images (`docker compose images`). Stockez une copie hors du serveur, avec accès restreint.

La commande `./whistor backup` existe aussi, mais utilise des noms de volumes
prédéfinis et ne suspend pas Synapse : vérifiez ces hypothèses avant de l’employer
pour une sauvegarde critique.

## Mettre à jour le code et les images

Sur **le serveur**, après sauvegarde :

```bash
cd /chemin/vers/Whistor
export WHISTOR_DIR="$PWD"
git pull --ff-only
./whistor update
```

`whistor update` télécharge les images de Synapse et Tor, reconstruit l’administration
avec les dernières images de base, puis recrée les conteneurs. Cette commande ne
fait **pas** de `git pull` à votre place. Vérifiez ensuite `docker compose ps`, les
logs et une connexion de test depuis votre PC.

## Restaurer

Restaurez d’abord dans un environnement isolé si possible. Utilisez les images et
le code correspondant à la sauvegarde. Arrêtez les services ; restaurez chaque
archive dans son volume correspondant, en conservant les propriétaires et permissions.
Rétablissez également `.env` avant le redémarrage.

Ne démarrez pas une ancienne version de Synapse sur une base ayant subi une migration
plus récente : revenir en arrière nécessite aussi la sauvegarde correspondante.
Ne lancez pas `docker compose down -v` sur votre déploiement pour résoudre un incident :
cela supprimerait les volumes et peut faire perdre définitivement l’adresse `.onion`.
