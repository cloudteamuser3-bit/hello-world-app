#!/usr/bin/env bash
# Writes the new image tag/digest directly into the environments repo's
# dev.yaml and pushes. This is the ONLY cross-repo communication this repo
# does, and it's plain git - clone, write a file, commit, push. That works
# identically whether the remote is GitHub, GitLab, or a bare repo on a
# USB stick. The only platform-specific piece is how VCS_TOKEN was minted
# (see the "PLATFORM SEAM" step in .github/workflows/ci.yml) - this script
# just needs a token with write access embedded in the clone URL.
#
# Usage: scripts/update_environment.sh <image_tag> <image_digest> <source_sha>
# Required env vars: VCS_TOKEN, VCS_ORG, ENVIRONMENTS_REPO
set -euo pipefail

IMAGE_TAG="${1:?Usage: update_environment.sh <image_tag> <image_digest> <source_sha>}"
IMAGE_DIGEST="${2:?missing image_digest}"
SOURCE_SHA="${3:?missing source_sha}"

: "${VCS_TOKEN:?VCS_TOKEN must be set}"
: "${VCS_ORG:?VCS_ORG must be set}"
: "${ENVIRONMENTS_REPO:?ENVIRONMENTS_REPO must be set}"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

REPO_URL="https://x-access-token:${VCS_TOKEN}@github.com/${VCS_ORG}/${ENVIRONMENTS_REPO}.git"

echo "==> Cloning ${ENVIRONMENTS_REPO}" >&2
git clone --depth 1 "$REPO_URL" "$WORKDIR"

cat > "$WORKDIR/environments/dev.yaml" <<EOF
image_tag: "${IMAGE_TAG}"
image_digest: "${IMAGE_DIGEST}"
promoted_from: "app-repo commit ${SOURCE_SHA}"
promoted_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
promoted_by: "automated"
EOF

cd "$WORKDIR"
git config user.name "promotion-bot"
git config user.email "promotion-bot@users.noreply.github.com"
git add environments/dev.yaml

if git diff --cached --quiet; then
  echo "No changes to commit" >&2
  exit 0
fi

git commit -m "Deploy ${IMAGE_TAG} to dev"
git push
