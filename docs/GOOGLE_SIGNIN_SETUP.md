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
   - Play copies: Lantern's Play app-signing key has been rotated, so the installed app carries a key
     history. Google's services identify it by the **original** key, so register every key in the
     history as its own Android client (2026-11-19: `7E:FA:E1:2B:84:4A:40:9D:B3:7A:D2:9A:DB:52:9E:52:3C:ED:26:F0`
     original, `B9:8E:3E:37:6D:7D:64:78:14:BA:68:FA:B3:81:C7:38:BB:AF:61:E4`,
     `45:75:55:F8:F2:EE:13:33:5A:68:D2:DB:BC:75:80:2B:0F:01:73:01` current). If sign-in fails, the app's error
     message lists the keys of the installed copy.
5. **Give the client ID to the builds**: GitHub repo → Settings → Secrets and variables → Actions →
   Variables → New repository variable `GOOGLE_CLIENT_ID` = the web client ID from step 3. The next
   build puts it in the phone app and the web version. (Until then it can be pasted in Settings →
   OAuth client ID in either app.)

Then: Settings → Google Drive sync → Sign in with Google, on the phone and in the web version.

Troubleshooting: `UNREGISTERED_ON_API_CONSOLE` or a "not set up for this app" error on the phone means a
missing SHA-1 (often the original Play key) or a wrong package name in step 4. The phone asks Google only for
Drive authorization (no Credential Manager sign-in), because that sign-in failed with "[16] Account reauth
failed" for this app. "Drive API is not turned on" means step 1.
"Access blocked / app not verified" means your account isn't a test user (step 2).
