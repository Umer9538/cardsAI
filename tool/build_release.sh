#!/usr/bin/env bash
#
# Release builds, with the defines they cannot ship without.
#
# Two things are invisible when they go wrong, which is why this is a script
# and not a habit:
#
#   * Ad units fall back to Google's TEST ids when the defines are absent.
#     A release built without them installs, runs, and serves test creatives
#     that earn nothing — silently, forever, until someone notices the revenue
#     line is flat.
#
#   * WORKER_URL has no default at all, so a build without it throws a
#     StateError the first time anyone scans anything.
#
# Neither shows up in `flutter analyze` or the test suite. Refusing to build is
# the only place they can be caught before a store review.
#
# Usage:
#   cp tool/release.env.example tool/release.env   # then fill it in, do not commit it
#   tool/build_release.sh appbundle
#   tool/build_release.sh ipa

set -euo pipefail

cd "$(dirname "$0")/.."

TARGET="${1:-appbundle}"
ENV_FILE="${ENV_FILE:-tool/release.env}"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi

fail() { printf '\n  release build refused: %s\n\n' "$1" >&2; exit 1; }

require() {
  local name="$1" value="${!1:-}"
  [[ -n "$value" ]] || fail "$name is not set. Put it in $ENV_FILE."
}

require WORKER_URL

# Ad ids are per platform, so only the ones this target actually uses are
# required — an Android bundle has no business needing the iOS unit.
case "$TARGET" in
  appbundle|apk) AD_SUFFIX=ANDROID ;;
  ipa|ios)       AD_SUFFIX=IOS ;;
  *) fail "unknown target '$TARGET' — expected appbundle, apk, ipa or ios" ;;
esac

REWARDED_VAR="ADMOB_REWARDED_${AD_SUFFIX}"
APP_OPEN_VAR="ADMOB_APP_OPEN_${AD_SUFFIX}"
require "$REWARDED_VAR"
require "$APP_OPEN_VAR"

# Google's test publisher id. Shipping it is the failure this script exists to
# prevent, and it is not caught by the emptiness check above.
TEST_PUBLISHER='ca-app-pub-3940256099942544'
for var in "$REWARDED_VAR" "$APP_OPEN_VAR"; do
  if [[ "${!var}" == *"$TEST_PUBLISHER"* ]]; then
    fail "$var is still Google's TEST unit. A release with it earns nothing."
  fi
done

# The AdMob *application* id lives in the manifest and plist rather than a
# define, and the app crashes at start-up without it — so it cannot be defaulted
# away, only got wrong.
if grep -q "$TEST_PUBLISHER" android/app/src/main/AndroidManifest.xml; then
  fail "AndroidManifest.xml still holds the test AdMob application id."
fi
if grep -q "$TEST_PUBLISHER" ios/Runner/Info.plist; then
  fail "Info.plist still holds the test AdMob application id (GADApplicationIdentifier)."
fi

echo "→ flutter build $TARGET --release"
exec flutter build "$TARGET" --release \
  --dart-define="WORKER_URL=$WORKER_URL" \
  --dart-define="$REWARDED_VAR=${!REWARDED_VAR}" \
  --dart-define="$APP_OPEN_VAR=${!APP_OPEN_VAR}"
