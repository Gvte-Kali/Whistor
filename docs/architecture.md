# Architecture et accès réseau

## Les trois services

```text
Client Matrix compatible Tor
    → réseau Tor → service .onion:8448 → synapse:8008

Navigateur sur votre PC (LAN / Tailscale / SSH)
    → serveur:8080 → admin (Ketesa + Nginx) → synapse:8008
```

| Service | Rôle | Réseaux Docker |
| --- | --- | --- |
| `synapse` | Serveur Matrix et base SQLite | `matrix-internal` |
| `tor` | Service caché et identité `.onion` | `matrix-internal`, `tor-external` |
| `admin` | Interface web et relais des API Synapse | `matrix-internal`, `admin-access` |

Seul `admin` publie un port sur le serveur. Synapse ne publie pas directement de
port hôte. Le navigateur utilise la même origine pour l’interface et les requêtes
Matrix : il n’a pas à résoudre `synapse`, nom interne à Docker.

## Modèle d’accès

- L’interface est accessible par le réseau choisi ; le compte administrateur est
  authentifié par Synapse, qui contrôle les droits sur les API.
- Le proxy relaie `/_matrix/` et `/_synapse/` vers Synapse. Une exposition publique
  du port d’administration expose donc également ces routes.
- Le conteneur d’administration n’a pas accès au socket Docker, aux clés Tor ni
  au volume de données Synapse. Il utilise une racine de fichiers en lecture seule
  avec des répertoires temporaires en mémoire.
- La fédération et l’inscription publique sont désactivées par la configuration
  par défaut. Cela ne remplace pas l’authentification et les règles du pare-feu.
- GitHub Pages héberge uniquement cette documentation publique. Il ne contient
  aucune instance de votre administration, aucun mot de passe ni aucune clé privée.

## Choisir l’exposition

Pour un réseau local, utilisez l’adresse LAN du serveur. Pour un accès distant
privé, Tailscale direct ou Tailscale Serve conviennent. Pour un accès distant sans
VPN, placez un reverse proxy HTTPS devant le service. Les variables de `.env`
permettent de choisir l’interface et le port sans modifier le fichier Compose.
