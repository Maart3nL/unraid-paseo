# syntax=docker/dockerfile:1
#
# Paseo + Claude Code — self-contained, Unraid-ready image.
#
# Paseo (https://paseo.sh) is an open-source coding-agent orchestrator. This
# Dockerfile reproduces Paseo's official base image (which is not published as a
# public, anonymously-pullable package) directly from the @getpaseo/* npm
# packages, and bakes in the Claude Code CLI so Paseo can launch Claude Code
# agents out of the box.
#
# Base build steps mirror github.com/getpaseo/paseo -> docker/base. The Paseo
# daemon + bundled web UI listen on :6767 and run as the non-root `paseo` user
# (uid/gid 1000). Agent credentials and daemon state persist under /home/paseo.

ARG NODE_IMAGE=node:22-bookworm-slim
FROM ${NODE_IMAGE}

ARG PASEO_VERSION=latest

ENV HOME=/home/paseo \
    PASEO_HOME=/home/paseo/.paseo \
    PASEO_LISTEN=0.0.0.0:6767 \
    PASEO_WEB_UI_ENABLED=true \
    PASEO_LOG_FORMAT=json \
    PASEO_LOG_LEVEL=info \
    CLAUDE_CONFIG_DIR=/home/paseo/.claude \
    CODEX_HOME=/home/paseo/.codex \
    XDG_CONFIG_HOME=/home/paseo/.config \
    XDG_DATA_HOME=/home/paseo/.local/share \
    XDG_STATE_HOME=/home/paseo/.local/state \
    XDG_CACHE_HOME=/home/paseo/.cache \
    ONNXRUNTIME_NODE_INSTALL=skip

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      gosu \
      openssh-client \
      tini; \
    rm -rf /var/lib/apt/lists/*

# Paseo daemon + CLI.
RUN set -eux; \
    npm install -g --omit=optional \
      "@getpaseo/server@${PASEO_VERSION}" \
      "@getpaseo/cli@${PASEO_VERSION}"; \
    npm cache clean --force; \
    server_entry="$(npm root -g)/@getpaseo/server/dist/scripts/supervisor-entrypoint.js"; \
    test -f "$server_entry"; \
    printf '%s\n' "$server_entry" > /etc/paseo-server-entry; \
    node --check "$server_entry"

# Claude Code agent CLI. `latest` floats; pin with --build-arg for reproducible
# builds. Installed before the user is dropped; the entrypoint runs it as `paseo`.
ARG CLAUDE_CODE_VERSION=latest
RUN set -eux; \
    npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"; \
    npm cache clean --force; \
    claude --version

# Non-root paseo user (uid/gid 1000), reusing the base node user's id if present.
RUN set -eux; \
    existing_group="$(getent group 1000 | cut -d: -f1 || true)"; \
    if [ -n "$existing_group" ] && [ "$existing_group" != "paseo" ]; then \
      groupmod --new-name paseo "$existing_group"; \
    elif [ -z "$existing_group" ]; then \
      groupadd --gid 1000 paseo; \
    fi; \
    existing_user="$(getent passwd 1000 | cut -d: -f1 || true)"; \
    if [ -n "$existing_user" ] && [ "$existing_user" != "paseo" ]; then \
      usermod --login paseo --gid paseo --home /home/paseo --shell /bin/bash "$existing_user"; \
    elif [ -z "$existing_user" ]; then \
      useradd --uid 1000 --gid paseo --create-home --home-dir /home/paseo --shell /bin/bash paseo; \
    fi; \
    mkdir -p \
      /workspace \
      "$PASEO_HOME" \
      "$CLAUDE_CONFIG_DIR" \
      "$CODEX_HOME" \
      "$XDG_CONFIG_HOME" \
      "$XDG_DATA_HOME" \
      "$XDG_STATE_HOME" \
      "$XDG_CACHE_HOME"; \
    chown -R paseo:paseo /home/paseo /workspace

COPY rootfs/ /
RUN chmod +x /usr/local/bin/paseo-docker-entrypoint

LABEL org.opencontainers.image.title="Paseo + Claude Code (Unraid)" \
      org.opencontainers.image.description="Paseo coding-agent orchestrator with the Claude Code CLI baked in, packaged for Unraid." \
      org.opencontainers.image.source="https://github.com/Maart3nL/unraid-paseo" \
      org.opencontainers.image.url="https://paseo.sh/" \
      org.opencontainers.image.licenses="AGPL-3.0"

WORKDIR /workspace

EXPOSE 6767
VOLUME ["/home/paseo"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "const listen=process.env.PASEO_LISTEN||'0.0.0.0:6767'; const m=listen.match(/:(\\d+)$/); const port=m?Number(m[1]):6767; require('http').get({hostname:'127.0.0.1',port,path:'/api/health'},r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/paseo-docker-entrypoint"]
