class Directgate < Formula
  desc "DirectGate secure remote agent"
  homepage "https://github.com/directgate/directgate"
  url "https://pkg.directgate.io/brew/directgate-1.0.20.tar.gz"
  version "1.0.20"
  sha256 "0c4439e9306cb7daac62a06bc8ef905db9d9ee0636e50d02afcbea674b08cddb"
  license "GPL-3.0-or-later"
  revision 3

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "openssl@3"
  # Runtime Opus encoder for desktop system audio (dlopen'd; video is
  # unaffected if absent). Screen/audio capture itself uses OS frameworks.
  depends_on "opus"

  resource "libdatachannel" do
    url "https://pkg.directgate.io/brew/libdatachannel-28b2e730f4c7.tar.gz"
    sha256 "b94e847d5c354d3985b9613f5bb61e1d0758bed6e4883eecf6af7a4a6b18d274"
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
