# Google sign-in setup (Drive sync)

One-time setup in the Google Cloud project that already holds the Text-to-Speech API key.
All of it is at https://console.cloud.google.com with that project selected.

1. **Turn on the Drive API**: APIs & Services → Library → search "Google Drive API" → Enable.
2. **Consent screen**: Google Auth Platform (or APIs & Services → OAuth consent screen).
   - Branding: app name `Lantern Reader`, your email as support and developer contact.
   - Audience: External. Either add your Gmail under *Test users*, or press *Publish app*
     (Lantern only asks for `drive.file`, a non-sensitive scope, so no Google review is needed).
   - Data access: add the scope `https://www.googleapis.com/auth/drive.file`.
3. **Web client** (used by the web version, and by the phone app to identify itself):
   Clients → Create client → *Web application*, name `Lantern web`,
   Authorized JavaScript origins: `https://lalli87.github.io`. Copy the client ID
   (`…apps.googleusercontent.com`).
4. **Android clients** (one per signing key), Clients → Create client → *Android*:
   - Package name `com.lalli87.lantern_reader`.
   - SHA-1 of the upload key: `93:D8:E8:16:8C:51:BA:C6:5F:91:62:D2:6C:C5:3B:4C:73:9A:68:39`
     (also printed in every GitHub Actions build log, step "Restore signing key from repo secrets").
     This key signs the APK from GitHub releases.
   - Create a second Android client with the SHA-1 from Play Console → Test and release → App
     integrity → *App signing key certificate*. This key signs the app installed from Play.
5. **Give the client ID to the builds**: GitHub repo → Settings → Secrets and variables → Actions →
   Variables → New repository variable `GOOGLE_CLIENT_ID` = the web client ID from step 3. The next
   build puts it in the phone app and the web version. (Until then it can be pasted in Settings →
   OAuth client ID in either app.)

Then: Settings → Google Drive sync → Sign in with Google, on the phone and in the web version.

Troubleshooting: a "not set up for this app" / client configuration error on the phone almost always
means a missing or wrong SHA-1 or package name in step 4. "Drive API is not turned on" means step 1.
"Access blocked / app not verified" means your account isn't a test user (step 2).
