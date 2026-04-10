cask "yapyap" do
  version "1.0.4"
  sha256 "a7102f83f5427f7f81aa9a116b8c88347fdb30a8a0a576027c3d4b808afb29e3"

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
