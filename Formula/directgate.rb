class Directgate < Formula
  desc "DirectGate secure remote agent"
  homepage "https://github.com/directgate/directgate"
  url "https://pkg.directgate.io/brew/directgate-1.0.21.tar.gz"
  version "1.0.21"
  sha256 "1defa6aad2c0e5cb9218b67d0cb6f95a8ccca11dc5ef5a1c1876b536403b4471"
  license "GPL-3.0-or-later"


  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "openssl@3"
  # Runtime Opus encoder for desktop system audio (dlopen'd; video is
  # unaffected if absent). Screen/audio capture itself uses OS frameworks.
  depends_on "opus"

  resource "libdatachannel" do
    url "https://pkg.directgate.io/brew/libdatachannel-28b2e730f4c7.tar.gz"
    sha256 "5639ff561e627820d465f1dbee62b7feb9407268a1d8341bc3c417d7fb0dbfc9"
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

      Remote desktop requires macOS 12.3 or newer. Grant DirectGate Screen
      Recording permission for capture and Accessibility permission for input
      in System Settings > Privacy & Security, then restart the service.
    EOS
  end

  test do
    assert_match "Usage", shell_output("#{bin}/dgcli -h 2>&1")
  end
end
