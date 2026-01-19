class Shipctl < Formula
  desc "Professional Docker deployment automation tool"
  homepage "https://github.com/arramandhanu/deploy-cli"
  url "https://github.com/arramandhanu/deploy-cli/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "86094d6c0ea9f8dfdb252a50f10d26e50fc8351c7f4bf929a7a40ee679392069"
  license "MIT"
  version "1.0.0"

  depends_on "bash"
  depends_on "git"

  def install
    prefix.install Dir["*"]
    bin.install_symlink prefix/"shipctl" => "shipctl"
    bash_completion.install "completions/shipctl.bash" => "shipctl"
  end

  def caveats
    <<~EOS
      Run 'shipctl init' in your project directory to get started.
    EOS
  end

  test do
    system "#{bin}/shipctl", "--version"
  end
end
