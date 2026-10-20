#!/usr/bin/env bash
# Baut das Relay-Image für x86 (amd64) und ARM (arm64) und speichert beide als .tar zum Importieren,
# z. B. in Synology Container Manager (Image → Hinzufügen → Aus Datei hinzufügen).
#   tools/relay/image_bauen.sh [zielordner]   (Standard /mnt/project-files/relay)
set -euo pipefail
cd "$(dirname "$0")"
OUT=${1:-/mnt/project-files/relay}
mkdir -p "$OUT"
docker info >/dev/null 2>&1 || { (dockerd >/tmp/dockerd.log 2>&1 &); for _ in $(seq 30); do docker info >/dev/null 2>&1 && break; sleep 1; done; }
for arch in amd64 arm64; do
  # Basis über den Google-Spiegel von Docker Hub (Docker Hub selbst drosselt geteilte IPs)
  docker buildx build --platform "linux/$arch" -t "tdhub-relay:latest" --build-arg BASE="${BASE:-mirror.gcr.io/library/python:3.12-alpine}" \
    --output "type=docker,dest=$OUT/tdhub-relay-$arch.tar" . >/dev/null
  echo "$OUT/tdhub-relay-$arch.tar ($(du -h "$OUT/tdhub-relay-$arch.tar" | cut -f1))"
done
