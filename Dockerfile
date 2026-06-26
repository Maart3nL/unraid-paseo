# syntax=docker/dockerfile:1
#
# Paseo + Claude Code — Unraid-ready image.
#
# Paseo (https://paseo.sh) is a coding-agent orchestrator. Its official image
# (ghcr.io/getpaseo/paseo) ships the daemon + bundled web UI on :6767 but
# deliberately leaves out the agent CLIs to stay small. This image is a thin
# child that bakes in the Claude Code CLI so Paseo can launch Claude Code
# agents with zero extra setup.
#
# Everything else — entrypoint, the non-root `paseo` user (uid/gid 1000),
# exposed port, volumes, healthcheck and env defaults — is inherited from the
# base image unchanged.

ARG PASEO_TAG=latest
FROM ghcr.io/getpaseo/paseo:${PASEO_TAG}

# Agent CLIs must be installed as root. The base entrypoint still drops the
# daemon and every launched agent back to the unprivileged `paseo` user.
USER root

# `latest` tracks the newest Claude Code release; pin it for reproducible builds
# by passing --build-arg CLAUDE_CODE_VERSION=x.y.z.
ARG CLAUDE_CODE_VERSION=latest
RUN set -eux; \
    npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"; \
    npm cache clean --force; \
    claude --version

LABEL org.opencontainers.image.title="Paseo + Claude Code (Unraid)" \
      org.opencontainers.image.description="Paseo coding-agent orchestrator with the Claude Code CLI baked in, packaged for Unraid." \
      org.opencontainers.image.source="https://github.com/Maart3nL/unraid-paseo" \
      org.opencontainers.image.url="https://paseo.sh/" \
      org.opencontainers.image.licenses="AGPL-3.0"
