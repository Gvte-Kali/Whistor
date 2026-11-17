# Your Matrix server. Your administration.

**Whistor** deploys a Matrix/Synapse messaging server with a Tor v3 hidden service
and a web interface to manage users from your own PC.

[Install Whistor](installation.md){ .md-button .md-button--primary }
[Manage users](administration.md){ .md-button }

## Two tasks, two access paths

| Task | On your PC | On the server |
| --- | --- | --- |
| Chat on Matrix | A Tor-compatible client such as **element-tor** | Synapse and Tor |
| Manage accounts | A browser over LAN, Tailscale or an SSH tunnel | The Docker `admin` service on port **8080** |

Open the browser on **your PC**, not on the machine hosting Whistor. Sign in to the
administration interface with a **Synapse administrator account**. Your Linux/SSH
account is separate.

## What you can manage

- Create, search and edit users.
- Reset passwords and assign administrator privileges.
- Deactivate accounts that should no longer have access.
- Use the additional tools provided by [Ketesa](https://github.com/etkecc/ketesa), the integrated administration interface.

Federation and public registration are disabled by default. Message encryption
depends on end-to-end encryption being enabled in your Matrix clients.

!!! info "Network scope"
    The `.onion` service remains available for Matrix. The administration service
    also exposes Synapse's client and administrator APIs on its configured network
    address. The entire deployment should therefore not be considered Tor-only.
    Read the [architecture guide](architecture.md) to choose your access model.

## Resources

- [Whistor source code](https://github.com/Gvte-Kali/Whistor)
- [Download element-tor](https://github.com/Gvte-Kali/element-tor/releases/latest)
- [IT-Projects catalogue](https://github.com/Gvte-Kali/IT-Projects)

Documentation checked on **November 17, 2026**, with Synapse `latest` and the
integrated administration service. Images tagged `latest` change over time:
review upstream release notes before upgrading.
