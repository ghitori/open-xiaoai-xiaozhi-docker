#!/usr/bin/env bash
# Build the image locally with Docker Buildx.
#
#   ./scripts/build-local.sh                 # latest upstream main, linux/amd64, load
#   IMAGE=me/xiaozhi ./scripts/build-local.sh
#   PLATFORMS=linux/amd64,linux/arm64 PUSH=1 ./scripts/build-local.sh
#
# Environment:
#   IMAGE          Image reference (default ghcr.io/ghitori/open-xiaoai-xiaozhi-docker)
#   VERSION        Tag version (default current date in Asia/Shanghai, YYYY.MM.DD)
#   PLATFORMS      Build platforms (default linux/amd64)
#   PUSH           1 to push instead of loading into the local engine
#   SUBMODULE_PIN  1 to build the committed submodule pin instead of upstream main
set -euo pipefail

cd "$(dirname "$0")/.."

if ! docker buildx version >/dev/null 2>&1; then
  echo "docker buildx is required" >&2
  exit 1
fi

if [[ "${SUBMODULE_PIN:-0}" == "1" ]]; then
  git submodule update --init --recursive open-xiaoai
else
  git submodule update --init --recursive --remote open-xiaoai
fi

./scripts/prepare-models.sh open-xiaoai

version="${VERSION:-$(TZ=Asia/Shanghai date +%Y.%m.%d)}"
image="${IMAGE:-ghcr.io/ghitori/open-xiaoai-xiaozhi-docker}"
platforms="${PLATFORMS:-linux/amd64}"
revision="$(git -C open-xiaoai rev-parse HEAD)"
short="$(git -C open-xiaoai rev-parse --short=7 HEAD)"
created="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

args=(
  buildx build
  --platform "${platforms}"
  --file open-xiaoai/examples/xiaozhi/Dockerfile
  --tag "${image}:${version}"
  --tag "${image}:latest"
  --tag "${image}:sha-${short}"
  --label "org.opencontainers.image.title=Open-XiaoAI x XiaoZhi AI"
  --label "org.opencontainers.image.source=https://github.com/ghitori/open-xiaoai-xiaozhi-docker"
  --label "org.opencontainers.image.revision=${revision}"
  --label "org.opencontainers.image.version=${version}"
  --label "org.opencontainers.image.created=${created}"
  --provenance=false
)

if [[ "${platforms}" == *,* ]]; then
  if [[ "${PUSH:-0}" != "1" ]]; then
    echo "Multi-platform builds require PUSH=1 (a local engine cannot load an index)." >&2
    exit 1
  fi
  args+=(--push)
elif [[ "${PUSH:-0}" == "1" ]]; then
  args+=(--push)
else
  args+=(--load)
fi

echo "Building ${image}:${version} from ${revision} (${platforms})"
docker "${args[@]}" open-xiaoai
echo "Done: ${image}:${version}"
