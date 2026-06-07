class Directgate < Formula
  desc "DirectGate secure remote agent"
  homepage "https://github.com/directgate/directgate-agent"
  url "https://pkg.directgate.io/brew/directgate-1.0.20.tar.gz"
  version "1.0.20"
  sha256 "7281491e5493f9a6356fdc48f3d2aeb28de02dc7aa0107e276ee6d84e59ff8d0"
  license "GPL-3.0-or-later"
  revision 1

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "openssl@3"

  resource "libdatachannel" do
    url "https://pkg.directgate.io/brew/libdatachannel-28b2e730f4c7.tar.gz"
    sha256 "0e8bd64b1aeef3ab97eb2e0ebbf39a0b844871bcc4fb21a6c9b2b292b8725a3e"
  end

  def install
    resource("libdatachannel").stage buildpath/"libdatachannel"

    inreplace "src/common/logger.c",
              '#define DIRECTGATE_LOG_PATH_DEFAULT "/var/log/directgate"',
              "#define DIRECTGATE_LOG_PATH_DEFAULT \"#{var}/log/directgate\""

    system "cmake", "-S", ".", "-B", "build",
           "-DCMAKE_BUILD_TYPE=Release",
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
