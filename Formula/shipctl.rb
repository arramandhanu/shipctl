class Shipctl < Formula
  desc "Professional Docker deployment automation tool"
  homepage "https://github.com/arramandhanu/shipctl"
  url "https://github.com/arramandhanu/shipctl/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"
  version "1.0.0"

  depends_on "bash"
  depends_on "git"

  def install
    prefix.install Dir["*"]
    bin.install_symlink prefix/"shipctl" => "shipctl"

    # Install shell completions
    bash_completion.install "completions/shipctl.bash" => "shipctl"
  end

  def caveats
    <<~EOS
      To get started:
        1. Initialize config in your project:
           cd /path/to/your/project
           shipctl init

        2. Edit configuration:
           nano deploy.env

        3. Run shipctl:
           shipctl --help
    EOS
  end

  test do
    system "#{bin}/shipctl", "--version"
  end
end
