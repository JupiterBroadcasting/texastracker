#!/usr/bin/env bash
set -euo pipefail

FILE="${1:-image.tar.gz}"

TAG=$(tar xOf "$FILE" manifest.json | jq -rc '.[].RepoTags[0]')

TAGNAME=$(echo "$TAG" | cut -d':' -f1)

echo "Loading docker image..."
docker load < "$FILE"

echo "Tagging docker image ${TAG} with ${TAGNAME}:latest"
docker tag "$TAG" "${TAGNAME}:latest"

echo "Loaded $TAG and tagged as ${TAGNAME}:latest"
