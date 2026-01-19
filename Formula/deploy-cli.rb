class DeployCli < Formula
  desc "Professional Docker deployment automation tool"
  homepage "https://github.com/arramandhanu/deploy-cli"
  url "https://github.com/arramandhanu/deploy-cli/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"
  version "1.0.0"

  depends_on "bash"
  depends_on "git"

  def install
    prefix.install Dir["*"]
    bin.install_symlink prefix/"deploy.sh" => "deploy"

    # Install shell completions
    bash_completion.install "completions/deploy.bash" => "deploy"
  end

  def caveats
    <<~EOS
      To get started:
        1. Copy the config template:
           cp #{prefix}/config/services.env.template #{prefix}/config/services.env

        2. Edit configuration:
           nano #{prefix}/config/services.env

        3. Run deploy:
           deploy --help
    EOS
  end

  test do
    system "#{bin}/deploy", "--version"
  end
end
