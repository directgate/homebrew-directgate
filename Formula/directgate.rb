class Directgate < Formula
  desc "DirectGate secure remote agent"
  homepage "https://github.com/directgate/directgate"
  url "https://pkg.directgate.io/brew/directgate-1.0.19.tar.gz"
  version "1.0.19"
  sha256 "4d851709d4f365448509b002039b3b84b6744a8700a6c1ceb7acb3dd174a4a7c"
  license "GPL-3.0-or-later"
  revision 5

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "openssl@3"

  resource "libdatachannel" do
    url "https://pkg.directgate.io/brew/libdatachannel-28b2e730f4c7.tar.gz"
    sha256 "71de0ee1b81c9b8b0bb5e0c6c6f822f98fbcaef4af640fa1396abff62d3bc185"
  end

  def install
    resource("libdatachannel").stage buildpath/"libdatachannel"

    inreplace "src/common/logger.c",
              '#define DIRECTGATE_LOG_PATH_DEFAULT "/var/log/directgate"',
              "#define DIRECTGATE_LOG_PATH_DEFAULT \"#{var}/log/directgate\""

    # Build channel tag appended to the agent version (1.0.19-5-brew_silicon).
    # Decided here because brew compiles on the user's machine, not in CI.
    build_tag = Hardware::CPU.arm? ? "brew_silicon" : "brew_intel"

    system "cmake", "-S", ".", "-B", "build",
           "-DCMAKE_BUILD_TYPE=Release",
           "-DDIRECTGATE_BUILD_TAG=#{build_tag}",
           "-DOPENSSL_ROOT_DIR=#{Formula["openssl@3"].opt_prefix}"
    system "cmake", "--build", "build"

    bin.install "build/directgate", "build/dgcli"
    doc.install "README.md", "LICENSE", "pkg/CHANGELOG.md"
  end

  def post_install
    (var/"log/directgate").mkpath
  end

  service do
    run [opt_bin/"directgate"]
    keep_alive true
    working_dir Dir.home
    log_path var/"log/directgate/directgate.log"
    error_log_path var/"log/directgate/directgate.log"
  end

  def caveats
    <<~EOS
      Log in in the browser to enroll your first device:
        https://directgate.io/login

      Then start the launchd service:
        brew services start directgate
    EOS
  end

  test do
    assert_match "Usage", shell_output("#{bin}/dgcli -h 2>&1")
  end
end
