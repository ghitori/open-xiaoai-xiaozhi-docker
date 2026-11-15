#!/usr/bin/env bash
# Download the official upstream VAD/KWS/ASR model bundle into the xiaozhi
# source tree so that it is copied into the Docker image by the upstream
# Dockerfile (COPY examples/xiaozhi .).
#
# Usage: scripts/prepare-models.sh [open-xiaoai-dir]
# Environment:
#   MODELS_URL  Override the bundle URL (defaults to the upstream release).
set -euo pipefail

repo_dir="${1:-open-xiaoai}"
dest="${repo_dir}/examples/xiaozhi"
models_dir="${dest}/xiaozhi/models"
url="${MODELS_URL:-https://github.com/idootop/open-xiaoai/releases/download/vad-kws-models/models.zip}"

required=(
  bpe.model
  tokens.txt
  silero_vad.onnx
  encoder.onnx
  decoder.onnx
  joiner.onnx
)

missing=0
for f in "${required[@]}"; do
  if [[ ! -s "${models_dir}/${f}" ]]; then
    missing=1
    break
  fi
done

if [[ "${missing}" -eq 0 ]]; then
  echo "Models already present in ${models_dir}"
  exit 0
fi

if [[ ! -d "${dest}" ]]; then
  echo "Not an open-xiaoai checkout: ${dest}" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

echo "Downloading models: ${url}"
curl -fL --retry 3 --retry-delay 2 -o "${tmp}/models.zip" "${url}"

python3 - "${tmp}/models.zip" "${dest}" <<'PY'
import sys
import zipfile
from pathlib import Path

zip_path = Path(sys.argv[1])
dest = Path(sys.argv[2])

with zipfile.ZipFile(zip_path) as archive:
    for info in archive.infolist():
        name = info.filename
        # Refuse absolute paths, drive letters and traversal.
        parts = Path(name).parts
        if name.startswith(("/", "\\")) or ".." in parts:
            raise SystemExit(f"unsafe path in archive: {name!r}")
    archive.extractall(dest)

print(f"Extracted {zip_path.name} into {dest}")
PY

for f in "${required[@]}"; do
  if [[ ! -s "${models_dir}/${f}" ]]; then
    echo "Missing model after extraction: ${models_dir}/${f}" >&2
    exit 1
  fi
done

du -sh "${models_dir}"
echo "Models ready in ${models_dir}"
