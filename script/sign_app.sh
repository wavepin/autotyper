#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIGN_DIR="$ROOT_DIR/.local-signing"
KEYCHAIN="$SIGN_DIR/autotyper.keychain-db"
IDENTITY="Autotyper Local Development"
umask 077
mkdir -p "$SIGN_DIR"
if [[ ! -f "$SIGN_DIR/certificate.pem" ]]; then
    openssl req -x509 -newkey rsa:2048 -nodes -keyout "$SIGN_DIR/private.pem" -out "$SIGN_DIR/certificate.pem" -days 3650 -subj "/CN=$IDENTITY/" -config "$ROOT_DIR/script/signing.cnf"
fi
if [[ ! -f "$SIGN_DIR/ready" ]]; then
    LEGACY_ARGS=()
    case "$(openssl version)" in "OpenSSL 3"*) LEGACY_ARGS=(-legacy);; esac
    openssl pkcs12 -export "${LEGACY_ARGS[@]}" -inkey "$SIGN_DIR/private.pem" -in "$SIGN_DIR/certificate.pem" -out "$SIGN_DIR/identity.p12" -passout pass:autotyper-local-import
    if [[ ! -f "$KEYCHAIN" ]]; then security create-keychain -p "" "$KEYCHAIN"; fi
    security unlock-keychain -p "" "$KEYCHAIN"
    security import "$SIGN_DIR/identity.p12" -k "$KEYCHAIN" -P "autotyper-local-import" -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$KEYCHAIN" >/dev/null
    rm "$SIGN_DIR/identity.p12" "$SIGN_DIR/private.pem"
    touch "$SIGN_DIR/ready"
fi
security unlock-keychain -p "" "$KEYCHAIN"
FINGERPRINT="$(openssl x509 -in "$SIGN_DIR/certificate.pem" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :)"
python3 - "$KEYCHAIN" "$FINGERPRINT" "$1" <<'SIGN'
import shlex, subprocess, sys
keychain, fingerprint, app = sys.argv[1:]
original = shlex.split(subprocess.check_output(['security', 'list-keychains', '-d', 'user'], text=True))
try:
    subprocess.run(['security', 'list-keychains', '-d', 'user', '-s', *original, keychain], check=True)
    subprocess.run(['codesign', '--force', '--sign', fingerprint, '--keychain', keychain, '--timestamp=none', '-r', f'=designated => identifier "local.autotyper.app" and certificate leaf = H"{fingerprint}"', app], check=True)
finally:
    subprocess.run(['security', 'list-keychains', '-d', 'user', '-s', *original], check=True)
SIGN
