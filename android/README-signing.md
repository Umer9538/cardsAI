# Signing

`android/key.properties` and `android/carbsai-upload.p12` are **gitignored**.
They are not in this repository and never should be.

## Back them up today

Losing the keystore means you can never publish an update to an app already on
Play under that key. There is no recovery and no support ticket that fixes it.
Copy both files to somewhere that is not this laptop — a password manager
attachment, an encrypted backup, anywhere with a second copy.

## Enrol in Play App Signing

When you first upload, accept Play App Signing. Google then holds the real
signing key and the one here becomes the *upload* key, which **can** be reset
if it is ever lost. That is the entire reason to enrol, and it is a one-time
choice you cannot change later.

## Register the certificate with Firebase

Firebase needs the release certificate's SHA-1 (and SHA-256, for App Check and
App Links) or a release build cannot sign in:

```bash
keytool -list -v -keystore android/carbsai-upload.p12 -alias carbsai
```

Paste both into Firebase console → Project settings → Your apps → Android →
Add fingerprint, then download the refreshed `google-services.json`.

**After enrolling in Play App Signing, do this again** with the certificate
Google shows on the App Signing page — that is what release builds served from
Play are actually signed with, and it is different from the upload key.

## Rebuilding the keystore from scratch

Only possible before the first upload. After that, the key is the app's
identity.

```bash
keytool -genkeypair -v -keystore android/carbsai-upload.p12 -storetype PKCS12 \
  -keyalg RSA -keysize 4096 -validity 10000 -alias carbsai
```
