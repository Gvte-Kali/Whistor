# Votre serveur Matrix, votre administration

**Whistor** déploie un serveur de messagerie Matrix/Synapse avec un service caché
Tor v3 et une interface web pour gérer vos utilisateurs depuis votre PC.

[Installer Whistor](installation.md){ .md-button .md-button--primary }
[Ouvrir l’administration](administration.md){ .md-button }

## Deux usages, deux points d’accès

| Besoin | Depuis votre PC | Sur le serveur |
| --- | --- | --- |
| Discuter sur Matrix | Un client compatible Tor, par exemple **element-tor** | Synapse et Tor |
| Gérer les comptes | Un navigateur, en LAN, via Tailscale ou tunnel SSH | Le service Docker `admin` sur le port **8080** |

Le navigateur s’ouvre sur **votre PC**, pas sur la machine qui héberge Whistor.
Vous vous connectez à l’administration avec un **compte administrateur Synapse**.
Votre compte Linux/SSH est distinct.

## Ce que vous pouvez gérer

- Créer, rechercher et modifier des utilisateurs.
- Réinitialiser leurs mots de passe et attribuer des droits administrateur.
- Désactiver les comptes qui ne doivent plus se connecter.
- Exploiter les autres fonctions de [Ketesa](https://github.com/etkecc/ketesa), l’interface d’administration intégrée.

La fédération et l’inscription publique sont désactivées par défaut. Les conversations
chiffrées dépendent du chiffrement de bout en bout activé dans les clients Matrix.

!!! info "Périmètre réseau"
    Le service `.onion` reste disponible pour Matrix. Le service d’administration
    expose aussi les API client et administrateur de Synapse sur son adresse réseau.
    Il ne faut donc pas considérer toute l’installation comme accessible uniquement par Tor.
    Consultez [l’architecture](architecture.md) pour choisir l’exposition adaptée.

## Ressources

- [Code source Whistor](https://github.com/Gvte-Kali/Whistor)
- [Télécharger element-tor](https://github.com/Gvte-Kali/element-tor/releases/latest)
- [Catalogue IT-Projects](https://github.com/Gvte-Kali/IT-Projects)

Documentation vérifiée le **17 novembre 2026**, avec Synapse `latest` et l’interface
web intégrée. Les images `latest` évolueront : consultez les notes upstream avant chaque mise à jour.
