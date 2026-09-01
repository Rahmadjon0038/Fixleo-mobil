# Encrypted mobile credentials

The tracked keys.tar.gz.enc bundle contains the complete mobile keys directory,
encrypted with AES-256-CBC and PBKDF2.

The password is never committed. Put it in .fixleo-key-bundle-password with
mode 600, or export FIXLEO_KEYS_PASSWORD, then run:

    ./scripts/restore-keys.sh

Plaintext credentials remain under the ignored keys directory.
