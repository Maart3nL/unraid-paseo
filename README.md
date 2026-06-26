# Paseo + Claude Code — for Unraid

An Unraid-ready Docker image for [**Paseo**](https://paseo.sh) — the open-source
orchestrator for coding agents — with the **Claude Code** CLI baked in so you
can launch Claude Code agents with zero extra setup.

It runs the Paseo daemon headless and serves the bundled **web UI on port
6767**. Open it in a browser, or connect from the Paseo desktop/mobile/CLI
clients. State and agent credentials persist on disk.

> Unofficial community packaging. Not affiliated with Paseo or Anthropic.
> The base image is AGPL-3.0; Claude Code is Anthropic proprietary. See [NOTICE](NOTICE).

---

## What's in the box

- Official Paseo daemon + web UI (`ghcr.io/getpaseo/paseo`) on `:6767`
- `@anthropic-ai/claude-code` pre-installed
- Multi-arch image (`linux/amd64`, `linux/arm64`) auto-built & published to GHCR
- Runs as non-root user `paseo` (uid/gid **1000**)

Image: `ghcr.io/maart3nl/unraid-paseo:latest`

---

## Install on Unraid

### Option A — add this template repo to Community Applications (easiest)

1. In Unraid, install **Community Applications** if you haven't.
2. **Settings → Community Applications → Manage** (or **Apps → Settings**) →
   **Template Repositories**.
3. Add this repository URL and save:
   ```
   https://github.com/Maart3nL/unraid-paseo
   ```
4. Go to the **Apps** tab, search **Paseo**, click it, and install.

### Option B — drop the template in by hand

Copy [`unraid/paseo.xml`](unraid/paseo.xml) to your Unraid box at:

```
/boot/config/plugins/dockerMan/templates-user/my-Paseo.xml
```

Then go to the **Docker** tab → **Add Container** → pick **Paseo** from the
*Template* dropdown.

### Then, in the template

| Setting | Notes |
| --- | --- |
| **WebUI Port** | `6767` (change the host port if it's taken) |
| **Password** | **Set this** before exposing the port — required to connect |
| **Paseo Home** → `/home/paseo` | defaults to `/mnt/user/appdata/paseo` — daemon state + agent creds |
| **Workspace** → `/workspace` | defaults to `/mnt/user/code` — code the agents can edit |
| **Anthropic API Key** | optional; leave blank to log in interactively (below) |
| **Allowed Hostnames** | only if you reach it by DNS name behind a reverse proxy |

Apply, then open the **WebUI** (the Paseo icon → *WebUI*) and enter your
password to connect.

---

## Sign Claude Code in

If you didn't pass an `ANTHROPIC_API_KEY`, log in once — credentials persist in
`/home/paseo/.claude`:

```bash
# Unraid: Docker tab → Paseo → Console, or from a shell:
docker exec -it -u paseo Paseo claude
```

Follow the prompts to authenticate. After that, agents launched by Paseo use
the stored credentials.

---

## Run anywhere (non-Unraid)

```bash
docker run -d --name paseo \
  -p 6767:6767 \
  -e PASEO_PASSWORD=change-me \
  -v "$PWD/paseo-home:/home/paseo" \
  -v "$PWD/workspace:/workspace" \
  ghcr.io/maart3nl/unraid-paseo:latest
```

…or use [`docker-compose.yml`](docker-compose.yml): `docker compose up -d`,
then open <http://localhost:6767>.

---

## Configuration reference

| Variable | Default | Purpose |
| --- | --- | --- |
| `PASEO_PASSWORD` | _(unset)_ | Auth password (hashed at startup). **Set it.** |
| `PASEO_HOSTNAMES` | _(unset)_ | Extra allowed Host headers behind a proxy, e.g. `paseo.example.com,.lan` |
| `ANTHROPIC_API_KEY` | _(unset)_ | Passed through to Claude Code; alternative to `claude` login |
| `PASEO_LISTEN` | `0.0.0.0:6767` | Listen address (inherited from base image) |
| `PASEO_WEB_UI_ENABLED` | `true` | Bundled web UI (inherited) |

| Volume | Purpose |
| --- | --- |
| `/home/paseo` | Paseo state (`.paseo`) + agent config/credentials (`.claude`, `.codex`) |
| `/workspace` | Code Paseo and its agents read/write |

Full daemon configuration: <https://paseo.sh/docs/configuration> ·
Docker notes: <https://github.com/getpaseo/paseo/blob/main/docs/docker.md>

---

## Security

- **Always set `PASEO_PASSWORD`** for any reachable deployment.
- Put HTTPS in front (reverse proxy) for browser access over the network, or use
  the Paseo relay / a tunnel (Tailscale, Cloudflare) for untrusted networks.
- The container is the isolation boundary: agents can read/write anything mounted
  into `/workspace` and any credentials in `/home/paseo`.

---

## Build it yourself

```bash
docker build -t paseo-claude .
# pin versions:
docker build \
  --build-arg PASEO_TAG=0.1.101 \
  --build-arg CLAUDE_CODE_VERSION=2.1.193 \
  -t paseo-claude:pinned .
```

The image is otherwise rebuilt automatically (push, weekly schedule, manual) by
[`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml),
which picks up new Paseo and Claude Code releases.

---

## Credits

- [Paseo](https://github.com/getpaseo/paseo) — the orchestrator (AGPL-3.0)
- [Claude Code](https://www.anthropic.com/claude-code) — Anthropic
