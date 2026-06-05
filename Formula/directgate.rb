class Directgate < Formula
  desc "DirectGate secure remote agent"
  homepage "https://github.com/directgate/directgate-agent"
  url "https://pkg.directgate.io/brew/directgate-1.0.18.tar.gz"
  version "1.0.18"
  sha256 "f2d184fcce79300dbe1661c445521ad4ebe5432b517d93dec2b41635ca1391ab"
  license "GPL-3.0-or-later"
  revision 1

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "openssl@3"

  resource "libdatachannel" do
    url "https://pkg.directgate.io/brew/libdatachannel-28b2e730f4c7.tar.gz"
    sha256 "e5a4182cad6dd10d75aa1c21f7be060eb0c11473e3689a6ffb8041f2fcb4b57e"
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

    (libexec/"directgate-brew-service").write <<~SH
      #!/bin/sh
      set -eu

      log() {
        printf '%s\\n' "$*" >&2
      }

      current_uid="$(id -u)"
      current_user="$(id -un 2>/dev/null || printf unknown)"

      if [ "$current_uid" = "0" ]; then
        log "DirectGate Homebrew service is intended to run as a user LaunchAgent."
        log "Stop the root service with: sudo brew services stop directgate"
        log "Start it as your user with: brew services start directgate"
        log "For a boot-time service, use: sudo brew services start directgate --sudo-service-user <user>"
        exit 0
      fi

      home=""
      if command -v dscl >/dev/null 2>&1; then
        home="$(dscl . -read "/Users/$current_user" NFSHomeDirectory 2>/dev/null | sed 's/^NFSHomeDirectory:[[:space:]]*//' | sed 's/^[[:space:]]*//' || true)"
      fi
      if [ -z "$home" ] && command -v getent >/dev/null 2>&1; then
        home="$(getent passwd "$current_user" 2>/dev/null | cut -d: -f6 || true)"
      fi
      if [ -z "$home" ] || [ ! -d "$home" ]; then
        home="${HOME:-}"
      fi
      if [ -z "$home" ] || [ ! -d "$home" ]; then
        log "DirectGate service could not determine a valid home directory for $current_user."
        exit 0
      fi

      config="$home/.config/directgate/agent.json"
      if [ ! -f "$config" ]; then
        log "DirectGate agent config not found: $config"
        log "Pair this device first, then restart the service:"
        log "  directgate -sed <device_id> -t <pairing_token>"
        log "  brew services restart directgate"
        exit 0
      fi
      if [ ! -r "$config" ]; then
        log "DirectGate agent config is not readable by $current_user: $config"
        exit 0
      fi

      owner_uid=""
      if owner_uid="$(stat -f %u "$config" 2>/dev/null)"; then
        :
      elif owner_uid="$(stat -c %u "$config" 2>/dev/null)"; then
        :
      else
        owner_uid=""
      fi

      if [ -n "$owner_uid" ] && [ "$owner_uid" != "$current_uid" ]; then
        log "DirectGate agent config owner does not match service user: $config"
        log "Expected uid $current_uid, found uid $owner_uid."
        log "Fix ownership or re-run pairing as $current_user."
        exit 0
      fi

      export HOME="$home"
      cd "$home"
      exec "#{opt_bin}/directgate" -c "$config"
    SH
    chmod 0755, libexec/"directgate-brew-service"
  end

  def post_install
    (var/"log/directgate").mkpath
  end

  service do
    run [opt_libexec/"directgate-brew-service"]
    keep_alive crashed: true
    restart_delay 5
    environment_variables PATH: std_service_path_env
    log_path var/"log/directgate/directgate.log"
    error_log_path var/"log/directgate/directgate.log"
  end

  def caveats
    <<~EOS
      Log in in the browser to enroll your first device:
        https://directgate.io/login

      Pair the device as the same macOS user that will run the service:
        directgate -sed <device_id> -t <pairing_token>

      Then start the user launchd service:
        brew services start directgate

      Do not use sudo for the normal Homebrew service. If a root service was
      created accidentally, remove it and start the user service:
        sudo brew services stop directgate
        brew services start directgate

      Service diagnostics are written to:
        #{var}/log/directgate/directgate.log
    EOS
  end

  test do
    assert_match "Usage", shell_output("#{bin}/dgcli -h 2>&1")
  end
end
