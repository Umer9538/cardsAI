# Signing

Three files are **gitignored**. They are not in this repository and never
should be — a signing key in a repository is a signing key that has been
published:

| File | What it is |
|---|---|
| `android/carbsai-upload.p12` | the upload key itself |
| `android/key.properties` | what Gradle reads to sign a release |
| `android/SIGNING-CREDENTIALS.md` | the password, fingerprints and this story in full |

## Handing the project over

**A git clone does not carry any of them.** That is the correct trade — but it
means a handover done purely through GitHub drops the lot silently, and the
person receiving it cannot publish an update and has no way to find out why
until they try. This section exists so the gap is visible from inside the
repository rather than discovered at an upload.

Transfer all three out of band: encrypted archive, or a shared
password-manager vault. Then verify on the other machine:

```bash
keytool -list -v -keystore android/carbsai-upload.p12 -alias carbsai
```

If that prints a certificate, the handover is complete. If it asks for a
password nobody has, stop — see "Rebuilding the keystore" at the foot of this
file, and note that it is only an option before the first Play upload.

## Back them up today

Losing the keystore means you can never publish an update to an app already on
Play under that key. There is no recovery and no support ticket that fixes it.
Copy all three to somewhere that is not this laptop — a password manager
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
