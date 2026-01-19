class Shipctl < Formula
  desc "Professional Docker deployment automation tool"
  homepage "https://github.com/arramandhanu/shipctl"
  url "https://github.com/arramandhanu/shipctl/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "7f47328b488d61052d08e432e96f6c07d4512775ed5edcc198b811caf9d679d9"
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
