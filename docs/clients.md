# Connecter un client Matrix

L’interface d’administration sur `:8080` sert à gérer le serveur. Pour la messagerie
via Tor, utilisez votre adresse de homeserver `.onion`.

## Trouver l’adresse du serveur

Sur **le serveur**, dans le dépôt Whistor :

```bash
export WHISTOR_DIR="$PWD"
./whistor onion
```

L’URL est de la forme :

```text
http://VOTRE_ADRESSE.onion:8448
```

Les identifiants Matrix locaux ressemblent à `@alice:VOTRE_ADRESSE.onion`.

## Desktop : element-tor

Téléchargez le paquet adapté à votre système depuis les
[releases element-tor](https://github.com/Gvte-Kali/element-tor/releases/latest).
La release **V-Tor.1.1** est basée sur Element **1.12.35** et propose :

| Système | Paquet |
| --- | --- |
| Linux x86_64 | AppImage |
| Windows x64 | MSI |
| macOS Intel | DMG ou ZIP x64 |
| macOS Apple Silicon | DMG ou ZIP arm64 |

Démarrez l’application et attendez la connexion Tor. Sur l’écran de connexion,
remplacez le serveur proposé par votre URL `.onion`, puis utilisez votre compte Matrix.

!!! note "Appels"
    Le fork bloque les tentatives d’ouverture d’Element Call : WebRTC/UDP n’est pas
    transporté par le proxy Tor. N’attendez pas de cette installation le fonctionnement
    des appels audio/vidéo d’un client standard.

## Autres clients et mobile

Un client doit pouvoir joindre et résoudre votre adresse `.onion` via Tor.
Sur Android, Orbot en mode VPN est une possibilité selon le client utilisé.
Sur iOS, les possibilités dépendent du client et des limites du système.

Ne supposez pas qu’un client Element standard possède une configuration SOCKS5
compatible. Vérifiez les fonctions de sa version. Utilisez element-tor sur Desktop
si vous souhaitez le proxy intégré du fork.

## Vérifier une première conversation

Créez un second compte depuis l’administration, connectez un client avec ce compte,
puis ouvrez une conversation. Activez le chiffrement de bout en bout si souhaité,
vérifiez les appareils et conservez les informations de récupération des clés.
Les clés de chiffrement des clients ne sont pas remplacées par une sauvegarde serveur.
