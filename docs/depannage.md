# Dépannage

## La page ne s’ouvre pas depuis mon PC

Sur le serveur :

```bash
docker compose ps
docker compose logs --tail=50 admin
docker compose port admin 8080
curl http://127.0.0.1:8080/health
```

Adaptez l’URL à l’adresse d’écoute et au port configurés. `127.0.0.1` dans le
navigateur de votre PC désigne **votre PC**, pas le serveur, sauf si un tunnel SSH
est actif. Vérifiez ensuite le pare-feu, le routage LAN, ou les politiques Tailscale.

Si `WHISTOR_ADMIN_BIND=127.0.0.1`, utilisez SSH/Tailscale Serve, ou choisissez une
adresse LAN/Tailscale dans `.env` puis recréez `admin`.

## La page s’affiche, mais Synapse ne répond pas

```bash
docker compose logs --tail=100 synapse tor
curl http://127.0.0.1:8080/_matrix/client/versions
```

La page statique peut être disponible avant que Synapse ait terminé son démarrage.
Au premier lancement, vérifiez que Tor a généré le hostname attendu et que les
volumes sont partagés correctement. Une erreur 502 peut aussi indiquer que Synapse
est arrêté ou ne peut pas être résolu depuis le réseau Docker interne.

## Connexion refusée ou droits insuffisants

Utilisez un compte **Synapse administrateur**, pas votre mot de passe SSH. Un
compte Matrix ordinaire ne peut pas gérer les utilisateurs. Pour créer un administrateur :

```bash
export WHISTOR_DIR="$PWD"
./whistor user admin nouveladmin
```

Évitez de modifier directement la base SQLite pendant que Synapse fonctionne.
Si vous avez déjà un compte du même nom, choisissez un autre nom ou utilisez un
administrateur existant pour lui attribuer les droits nécessaires.

## Tailscale fonctionne, mais pas l’interface

Vérifiez que les deux appareils sont connectés au même tailnet, que le serveur
écoute sur son IP Tailscale ou `0.0.0.0`, et que les politiques autorisent TCP 8080.
Avec Serve, utilisez `tailscale serve status` et l’URL HTTPS affichée. Si vous avez
changé le port Docker, mettez aussi à jour la cible de Serve.

## Un port est déjà utilisé

Changez `WHISTOR_ADMIN_PORT` dans `.env`, puis :

```bash
docker compose up -d --build admin
```

Pour SSH, vous pouvez aussi choisir uniquement un autre port **local**, comme
`18080`, tout en conservant `8080` sur le serveur.

## La CLI cherche le mauvais dossier

Depuis le dossier contenant `docker-compose.yml` :

```bash
export WHISTOR_DIR="$PWD"
./whistor admin
```

Ce paramètre évite le chemin par défaut de certaines installations de la CLI.

## Après une mise à jour

Consultez les logs, les notes de migration Synapse et votre sauvegarde. Ne supprimez
pas les volumes. Voir [maintenance](maintenance.md) pour préparer une restauration.
Pour signaler un problème sur [GitHub](https://github.com/Gvte-Kali/Whistor/issues),
joignez la version de Docker, le commit du dépôt et des logs sans identifiants,
jetons, secrets ni clés privées.
