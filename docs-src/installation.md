# Install Whistor

## Prepare your server

Use a Linux server with Docker and the Docker Compose v2 plugin. Debian and Ubuntu
are suitable choices. Allow at least 1 GB of RAM and 10 GB of storage, with more
capacity for additional users and media.

Your account must be able to run Docker. The server needs connectivity to download
images and join the Tor network. Your administration PC needs access to the server
over LAN, Tailscale or SSH.

```bash
docker --version
docker compose version
git --version
```

## Deploy from Git

On **the server**:

```bash
git clone https://github.com/Gvte-Kali/Whistor.git
cd Whistor
export WHISTOR_DIR="$PWD"
cp .env.example .env
docker compose up -d --build
```

The default configuration publishes administration on **all IPv4 interfaces,
port 8080**. Edit `.env` before starting if you want a different bind address or
port. See [access options](administration.md).

!!! tip "Run the CLI from your checkout"
    These guides use `./whistor`. Keep `WHISTOR_DIR` set to your checkout's absolute
    path in the current shell. After reconnecting over SSH, return to that directory
    and run `export WHISTOR_DIR="$PWD"` again. This avoids relying on the installed
    CLI's default directory.

## Check the first startup

```bash
docker compose ps
docker compose logs --tail=50 tor synapse admin
./whistor onion
```

Tor creates the `.onion` identity in its volume. Synapse waits for that hostname
before generating configuration and secrets. The first startup can take several
minutes. Do not delete volumes to speed it up.

## Create your administrator

Once Synapse is running:

```bash
./whistor user admin myadmin
```

Enter a password at the prompt. If you already have an administrator, use the
existing account instead of recreating it.

On **your PC**, open `http://SERVER_IP:8080` and sign in with this account.
The interface detects the homeserver automatically.

[Configure LAN or Tailscale access](administration.md){ .md-button }

## Automated installer

The repository also provides `install.sh`. It downloads the project files, builds
the administration service and installs the CLI when permissions allow it. To
review the script before executing it:

```bash
curl -fsSL https://raw.githubusercontent.com/Gvte-Kali/Whistor/main/install.sh -o install.sh
less install.sh
bash install.sh
```

Check the installation directory printed by the script and set `WHISTOR_DIR` if
your CLI points elsewhere. The Git method above is recommended for a reproducible
checkout and future source updates.
