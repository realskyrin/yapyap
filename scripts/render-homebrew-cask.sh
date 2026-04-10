#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

VERSION="${1:-}"
SHA256="${2:-}"
OUTPUT_PATH="${3:-$PROJECT_ROOT/Casks/yapyap.rb}"

if [[ -z "$VERSION" || -z "$SHA256" ]]; then
  echo "Usage: $0 <version> <sha256> [output-path]" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

cat > "$OUTPUT_PATH" <<EOF
cask "yapyap" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/realskyrin/yapyap/releases/download/release-v#{version}/yapyap-#{version}-arm64.zip",
      verified: "github.com/realskyrin/yapyap/"
  name "yapyap"
  desc "Lightweight menu bar voice input tool"
  homepage "https://github.com/realskyrin/yapyap"

  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  app "yapyap.app"

  uninstall quit: "cn.skyrin.yapyap"

  zap trash: [
    "~/.cache/huggingface/hub/models--mlx-community--Qwen3-4B-Instruct-2507-4bit",
    "~/Library/Application Support/yapyap",
    "~/Library/Caches/models/mlx-community/Qwen3-4B-Instruct-2507-4bit",
    "~/Library/Preferences/cn.skyrin.yapyap.plist",
    "~/Library/Saved Application State/cn.skyrin.yapyap.savedState",
  ]

  caveats do
    <<~EOS
      yapyap is currently not notarized. If macOS blocks the first launch, remove the quarantine attribute:
        xattr -dr com.apple.quarantine "#{appdir}/yapyap.app"
    EOS
  end
end
EOF
