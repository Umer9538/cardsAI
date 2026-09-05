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
#   tool/build_release.sh apk --dev      # for your own phone, before the store
#
# --dev exists because the store gates below are correct and currently refuse:
# there are no real ad units yet and LegalOperator is still placeholders. That
# left no way to get a testable build out of this script, so one got built by
# hand instead — and a hand-typed `flutter build apk --release` has no
# WORKER_URL, which surfaced on a phone as the AI scan showing a blank grey
# screen. A mode that keeps the gates a build needs to *work* and downgrades the
# ones a build needs to *ship* is what stops the whole script being bypassed.

set -euo pipefail

cd "$(dirname "$0")/.."

TARGET="${1:-appbundle}"
DEV=0
for arg in "$@"; do
  [[ "$arg" == "--dev" ]] && DEV=1
done
[[ "$TARGET" == "--dev" ]] && TARGET=appbundle
ENV_FILE="${ENV_FILE:-tool/release.env}"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi

fail() { printf '\n  release build refused: %s\n\n' "$1" >&2; exit 1; }

# A gate that only matters for the store, not for whether the build works.
# Refuses a real release; warns loudly on --dev and carries on.
store_gate() {
  if (( DEV )); then
    printf '  not for the store: %s\n' "$1" >&2
  else
    fail "$1"
  fi
}

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
    store_gate "$var is still Google's TEST unit. A release with it earns nothing."
  fi
done

# The AdMob *application* id lives in the manifest and plist rather than a
# define, and the app crashes at start-up without it — so it cannot be defaulted
# away, only got wrong.
if grep -q "$TEST_PUBLISHER" android/app/src/main/AndroidManifest.xml; then
  store_gate "AndroidManifest.xml still holds the test AdMob application id."
fi
if grep -q "$TEST_PUBLISHER" ios/Runner/Info.plist; then
  store_gate "Info.plist still holds the test AdMob application id (GADApplicationIdentifier)."
fi

# The privacy policy and terms are shipped inside the binary, and both stores
# read them. `LegalOperator` holds the three things a policy cannot be written
# without, as deliberately obvious placeholders — a plausible-looking wrong
# support address would ship silently, these do not.
if grep -q 'REPLACE-WITH-YOUR' lib/features/settings/presentation/legal_content.dart; then
  store_gate "legal_content.dart still has REPLACE-WITH-YOUR placeholders. Fill in LegalOperator (legal name, support email, jurisdiction) before shipping a policy."
fi

# A release signed with the debug key installs and runs. Both stores reject it,
# but only at upload — after the build. Catch it here instead.
case "$TARGET" in
  appbundle|apk)
    [[ -f android/key.properties ]] ||
      fail "android/key.properties is missing, so this would be signed with the DEBUG key. See android/README-signing.md."
    ;;
esac

if (( DEV )); then
  printf '\n  --dev: the warnings above are fine for your own phone and are a\n'
  printf '  store rejection. WORKER_URL and signing were still enforced.\n\n'
fi

echo "→ flutter build $TARGET --release"
# Obfuscated, with the symbols kept where they can be uploaded to the store's
# crash reporting. Without --split-debug-info the symbol file is discarded and
# a stack trace from a real device is unreadable.
exec flutter build "$TARGET" --release \
  --obfuscate \
  --split-debug-info=build/symbols \
  --dart-define="WORKER_URL=$WORKER_URL" \
  --dart-define="$REWARDED_VAR=${!REWARDED_VAR}" \
  --dart-define="$APP_OPEN_VAR=${!APP_OPEN_VAR}"
