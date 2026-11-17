# Interface web et utilisateurs

## Choisir votre mode d’accès

| Mode | Adresse à ouvrir sur votre PC | Prérequis |
| --- | --- | --- |
| LAN, sans VPN | `http://IP_LOCALE_DU_SERVEUR:8080` | Même réseau ou routage LAN ; pare-feu autorisant TCP 8080 |
| Tailscale direct | `http://IP_TAILSCALE_DU_SERVEUR:8080` | Deux machines dans le même tailnet ; politique autorisant TCP 8080 |
| Tailscale Serve | URL HTTPS affichée par Tailscale | Serve/HTTPS activé pour le tailnet |
| SSH | `http://localhost:8080` après le tunnel | Accès SSH au serveur |
| Internet sans VPN | Votre nom de domaine en HTTPS | Reverse proxy HTTPS configuré sur le serveur |

## LAN : le chemin le plus direct

Le service écoute par défaut sur `0.0.0.0:8080`. Depuis votre PC, ouvrez
`http://192.168.1.42:8080` en remplaçant cette IP par celle de votre serveur.
Aucune configuration de proxy Matrix ou de Tor n’est nécessaire pour l’administration.

Le pare-feu du serveur et les règles réseau doivent permettre cet accès. N’ouvrez
que les réseaux souhaités ; aucun changement automatique du pare-feu n’est effectué.

## Tailscale direct

Installez Tailscale sur **le serveur et votre PC**, connectez-les au même tailnet,
puis consultez l’adresse du serveur :

```bash
tailscale ip -4
```

Depuis votre PC, ouvrez `http://ADRESSE_AFFICHEE:8080`. Les politiques du tailnet
doivent autoriser votre PC à joindre ce port. Il n’est pas nécessaire de rediriger
un port public sur votre routeur.

## Tailscale Serve avec HTTPS

Sur **le serveur** :

```bash
tailscale serve --bg http://127.0.0.1:8080
tailscale serve status
```

Ouvrez l’URL HTTPS affichée depuis votre PC connecté au tailnet. Tailscale peut
vous demander d’activer Serve et HTTPS. Il s’agit de **Serve**, pas de Funnel :
l’accès reste privé au tailnet.

Si vous souhaitez uniquement ce mode d’accès, définissez
`WHISTOR_ADMIN_BIND=127.0.0.1` dans `.env` et recréez le service.

## Tunnel SSH

Lancez cette commande sur **votre PC** et gardez le terminal ouvert :

```bash
ssh -N -L 8080:127.0.0.1:8080 UTILISATEUR@SERVEUR
```

Ouvrez ensuite `http://localhost:8080`. Si le port local est déjà utilisé :

```bash
ssh -N -L 18080:127.0.0.1:8080 UTILISATEUR@SERVEUR
```

Dans ce cas, utilisez `http://localhost:18080` dans votre navigateur.

## Changer le port ou l’adresse d’écoute

Dans `.env`, à côté de `docker-compose.yml` :

```dotenv
WHISTOR_ADMIN_BIND=0.0.0.0
WHISTOR_ADMIN_PORT=8080
```

| Adresse d’écoute | Effet |
| --- | --- |
| `0.0.0.0` | Toutes les interfaces IPv4, dont LAN et Tailscale |
| IP LAN du serveur | Uniquement cette interface |
| IP Tailscale du serveur | Uniquement cette interface ; elle doit exister au démarrage |
| `127.0.0.1` | Accès local, SSH, Tailscale Serve ou reverse proxy local |

Appliquez les changements sur **le serveur** :

```bash
docker compose up -d --build admin
```

Adaptez aussi les URL et les tunnels si vous changez le port.

## Gérer les comptes

1. Connectez-vous avec votre administrateur **Synapse**, distinct du compte Linux.
2. Dans la liste des utilisateurs, recherchez un compte ou créez-en un.
3. Modifiez son nom affiché, son mot de passe ou ses droits selon le besoin.
4. Pour retirer l’accès, désactivez le compte. La désactivation ne signifie pas
   automatiquement l’effacement de toutes les données.
5. Conservez au moins un administrateur fonctionnel et déconnectez-vous à la fin.

Les droits sont contrôlés par Synapse : un utilisateur ordinaire ne peut pas
utiliser les API d’administration, même s’il peut afficher la page de connexion.

## Internet sans VPN

Placez un reverse proxy HTTPS devant `http://127.0.0.1:8080`. Utilisez un nom de
domaine dédié à la racine `/`, conservez l’en-tête `Host` et envoyez
`X-Forwarded-Proto: https`. Les déploiements dans un sous-chemin ne sont pas pris en charge.

N’envoyez pas vos identifiants administrateur sur Internet en HTTP : utilisez HTTPS.
L’exposition du proxy rend également les API Matrix relayées accessibles à cette
adresse ; choisissez vos règles d’accès réseau en conséquence.
