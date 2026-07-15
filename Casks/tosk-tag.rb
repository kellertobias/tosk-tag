cask "tosk-tag" do
  version :latest
  sha256 :no_check

  url "https://github.com/kellertobias/tosk-tag.git",
      branch: "main",
      using:  :git
  name "Tosk Tag"
  desc "Bulk editor for MP3 metadata"
  homepage "https://github.com/kellertobias/tosk-tag"

  depends_on formula: "lame"
  depends_on macos: :ventura

  app "Tobisk Tag Editor.app"

  preflight do
    system_command "/usr/bin/env",
                   args: ["bash", "#{staged_path}/scripts/build-homebrew-cask.sh"]
  end
end
