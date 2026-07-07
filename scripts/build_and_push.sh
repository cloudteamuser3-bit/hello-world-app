#!/usr/bin/env bash
# Builds and pushes the image. Requires GCP credentials already available
# to `gcloud`/`docker` (e.g. via the runner's attached service account) -
# this script itself has zero knowledge of which CI platform invoked it.
#
# Usage: scripts/build_and_push.sh <image_tag>
# Writes two lines to stdout: IMAGE_TAG=... and IMAGE_DIGEST=...
set -euo pipefail

IMAGE_TAG="${1:?Usage: build_and_push.sh <image_tag>}"

eval "$(python3 "$(dirname "$0")/read_config.py")"

IMAGE="${REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${AR_REPOSITORY}/${IMAGE_NAME}"

echo "==> Configuring Docker for Artifact Registry" >&2
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

echo "==> Building ${IMAGE}:${IMAGE_TAG}" >&2
docker build --tag "${IMAGE}:${IMAGE_TAG}" --tag "${IMAGE}:latest" .

echo "==> Pushing" >&2
docker push "${IMAGE}:${IMAGE_TAG}"
docker push "${IMAGE}:latest"

DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "${IMAGE}:${IMAGE_TAG}" | cut -d'@' -f2)

echo "IMAGE_TAG=${IMAGE_TAG}"
echo "IMAGE_DIGEST=${DIGEST}"
