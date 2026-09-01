#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUNDLE="${REPO_DIR}/secure/keys.tar.gz.enc"
CHECKSUM_FILE="${BUNDLE}.sha256"
PASSWORD_FILE="${FIXLEO_KEYS_PASSWORD_FILE:-${REPO_DIR}/.fixleo-key-bundle-password}"

fail() {
  printf '[restore-keys] %s\n' "$*" >&2
  exit 1
}

[[ -s "$BUNDLE" ]] || fail "Encrypted bundle topilmadi: $BUNDLE"
[[ -s "$CHECKSUM_FILE" ]] || fail "Bundle checksum topilmadi: $CHECKSUM_FILE"
if [[ -z "${FIXLEO_KEYS_PASSWORD:-}" && ! -s "$PASSWORD_FILE" ]]; then
  fail "FIXLEO_KEYS_PASSWORD yoki $PASSWORD_FILE kerak"
fi

expected_hash="$(awk 'NR == 1 { print $1 }' "$CHECKSUM_FILE")"
actual_hash="$(openssl dgst -sha256 "$BUNDLE" | awk '{ print $NF }')"
[[ "$actual_hash" == "$expected_hash" ]] || fail "Encrypted bundle checksum noto'g'ri"

umask 077
tmp_dir="$(mktemp -d)"
cleanup() {
  find "$tmp_dir" -type f -delete 2>/dev/null || true
  rmdir "$tmp_dir" 2>/dev/null || true
}
trap cleanup EXIT

pass_args=(-pass "file:$PASSWORD_FILE")
if [[ -n "${FIXLEO_KEYS_PASSWORD:-}" ]]; then
  pass_args=(-pass env:FIXLEO_KEYS_PASSWORD)
fi

openssl enc -d -aes-256-cbc -md sha256 -pbkdf2 -iter 200000 \
  -in "$BUNDLE" \
  -out "$tmp_dir/keys.tar.gz" \
  "${pass_args[@]}" >/dev/null 2>&1 ||
  fail "Bundle ochilmadi: parol noto'g'ri yoki fayl buzilgan"

while IFS= read -r entry; do
  case "$entry" in
    keys/|keys/prod/|keys/AuthKey_G3URM24LKX.p8|keys/GoogleService-Info.plist|keys/fixleo-production-firebase-adminsdk-fbsvc-2f8d48f9f3.json|keys/google-services.json|keys/prod/key.properties|keys/prod/upload-keystore.jks|keys/prod/upload_certificate.pem) ;;
    *) fail "Bundle ichida kutilmagan path bor: $entry" ;;
  esac
done < <(tar -tzf "$tmp_dir/keys.tar.gz")

tar -xzf "$tmp_dir/keys.tar.gz" -C "$REPO_DIR"

[[ -s "$REPO_DIR/keys/AuthKey_G3URM24LKX.p8" ]] || fail "APNs key restore bo'lmadi"
[[ -s "$REPO_DIR/keys/fixleo-production-firebase-adminsdk-fbsvc-2f8d48f9f3.json" ]] ||
  fail "Firebase Admin key restore bo'lmadi"
[[ -s "$REPO_DIR/keys/prod/upload-keystore.jks" ]] || fail "Android keystore restore bo'lmadi"
openssl pkey -in "$REPO_DIR/keys/AuthKey_G3URM24LKX.p8" -noout >/dev/null 2>&1 ||
  fail "APNs private key noto'g'ri"

find "$REPO_DIR/keys" -type d -exec chmod 700 {} +
find "$REPO_DIR/keys" -type f -exec chmod 600 {} +
printf '[restore-keys] Mobile keylar tiklandi.\n'
