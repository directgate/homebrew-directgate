class Directgate < Formula
  desc "DirectGate secure remote agent"
  homepage "https://github.com/directgate/directgate"
  url "https://pkg.directgate.io/brew/directgate-1.0.19.tar.gz"
  version "1.0.19"
  sha256 "9a7d05c0b36e64ed0a5e4cca20ccd8b8764012fa6617a3501d04976d48bbbcf2"
  license "GPL-3.0-or-later"
  revision 8

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "openssl@3"

  resource "libdatachannel" do
    url "https://pkg.directgate.io/brew/libdatachannel-28b2e730f4c7.tar.gz"
    sha256 "44405c39960bcffe42a7c07167c1bd77e0c4d6d625e9c7542240adf33153be10"
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
