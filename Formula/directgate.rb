class Directgate < Formula
  desc "DirectGate secure remote agent"
  homepage "https://github.com/directgate/directgate-agent"
  url "https://pkg.directgate.io/brew/directgate-1.0.18.tar.gz"
  version "1.0.18"
  sha256 "29360a055b4cb88da2c1a6a3d81e47f156793d06f33c5aefdea50c9cb1cfe76a"
  license "GPL-3.0-or-later"


  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "openssl@3"

  resource "libdatachannel" do
    url "https://pkg.directgate.io/brew/libdatachannel-28b2e730f4c7.tar.gz"
    sha256 "df44a268208ef320bc1c8dd40eb93a996492855a78e19c6f17b8c93e15cf8cca"
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
