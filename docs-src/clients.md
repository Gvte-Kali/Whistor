# Connect a Matrix client

The administration interface on `:8080` manages your server. For messaging over
Tor, use your `.onion` homeserver address.

## Find the homeserver address

On **the server**, from the Whistor checkout:

```bash
export WHISTOR_DIR="$PWD"
./whistor onion
```

The URL has this format:

```text
http://YOUR_ADDRESS.onion:8448
```

Local Matrix user IDs look like `@alice:YOUR_ADDRESS.onion`.

## Desktop: element-tor

Download the package for your platform from the
[element-tor releases](https://github.com/Gvte-Kali/element-tor/releases/latest).
Release **V-Tor.1.1** is based on Element **1.12.35** and provides:

| Platform | Package |
| --- | --- |
| Linux x86_64 | AppImage |
| Windows x64 | MSI |
| macOS Intel | x64 DMG or ZIP |
| macOS Apple Silicon | arm64 DMG or ZIP |

Launch the application and wait for Tor to connect. On the login screen, replace
the suggested server with your `.onion` URL, then sign in with your Matrix account.

!!! note "Calls"
    The fork blocks attempts to open Element Call: WebRTC/UDP is not carried by
    the Tor proxy. Do not expect the audio/video calling features of a standard
    client to work in this setup.

## Other clients and mobile

A client must be able to reach and resolve your `.onion` address through Tor.
On Android, Orbot's VPN mode is an option depending on the client. On iOS,
availability depends on the client and operating system limitations.

Do not assume that a standard Element client includes compatible SOCKS5 settings.
Check the features of the version you use. Choose element-tor on Desktop if you
want the fork's integrated proxy.

## Check your first conversation

Create a second account through the administration interface, sign in with it
from another client and start a conversation. Enable end-to-end encryption as
needed, verify your devices and retain your key recovery information. Server
backups do not replace client encryption key backups.
