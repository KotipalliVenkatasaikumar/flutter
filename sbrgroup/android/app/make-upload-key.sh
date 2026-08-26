#!/usr/bin/env bash
#
# Creates Ajna's Play upload key and the keystore.properties that points at it.
#
# WHY THIS IS A SCRIPT AND NOT A COMMAND YOU PASTE
#
# The password is read from a prompt with echo off, used in place, and written
# only to keystore.properties. It never appears in your shell history, in a
# process list, or in any transcript.
#
# THIS KEY IS PERMANENT. Play ties the listing to it. Lose the .jks or forget
# the password and com.corenuts.ajna can never be updated again — the only way
# back is a Play key reset, which takes days and needs Google's help. BACK BOTH
# UP somewhere off this machine before you upload.
#
# Safe to abort: nothing is written until keytool has succeeded.
#
# Usage:  bash android/app/make-upload-key.sh
set -euo pipefail

cd "$(dirname "$0")"

STORE_DIR="keystore"
STORE_FILE="$STORE_DIR/upload-keystore.jks"
PROPS="keystore.properties"
ALIAS="upload"

if [ -f "$STORE_FILE" ]; then
  echo "REFUSING: $STORE_FILE already exists."
  echo "Overwriting it would orphan any build already signed with it."
  echo "Move it aside first if you really mean to replace it."
  exit 1
fi

echo "Creating the Play upload key for com.corenuts.ajna"
echo

# Read twice and compare — a typo here is unrecoverable once the app is live.
read -r -s -p "Choose a keystore password (min 6 chars): " PW1; echo
read -r -s -p "Type it again to confirm: " PW2; echo
if [ "$PW1" != "$PW2" ]; then
  echo "Passwords do not match. Nothing was created."
  exit 1
fi
if [ ${#PW1} -lt 6 ]; then
  echo "keytool requires at least 6 characters. Nothing was created."
  exit 1
fi

mkdir -p "$STORE_DIR"

# The distinguished name is not shown to users; Play only needs a valid cert.
# 10000 days keeps it valid past any plausible life of the listing — Play
# rejects a key that expires before 2033.
keytool -genkeypair -v \
  -keystore "$STORE_FILE" \
  -alias "$ALIAS" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PW1" -keypass "$PW1" \
  -dname "CN=Ajna, OU=Mobile, O=Corenuts, L=Hyderabad, S=Telangana, C=IN"

# Same password for store and key: Play's own docs use one, and a second
# password is one more thing to lose without buying any protection here.
umask 077
cat > "$PROPS" <<EOF
storePassword=$PW1
keyPassword=$PW1
keyAlias=$ALIAS
storeFile=$STORE_FILE
EOF
chmod 600 "$PROPS"

unset PW1 PW2

echo
echo "Created:"
echo "  android/app/$STORE_FILE"
echo "  android/app/$PROPS   (chmod 600)"
echo
echo "Both are already covered by .gitignore, so neither will be committed."
echo
echo "The certificate Play will bind the listing to:"
keytool -list -v -keystore "$STORE_FILE" -alias "$ALIAS" \
  -storepass "$(sed -n 's/^storePassword=//p' "$PROPS")" 2>/dev/null \
  | grep -E "Alias name|Owner|Valid from|SHA-256" || true
echo
echo "NEXT: back up the .jks and the password off this machine, then rebuild."
