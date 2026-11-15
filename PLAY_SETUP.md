# Putting Lantern Reader on Google Play

This works the same way as Bolo Notes: every push to `main` builds a new version, publishes a GitHub release, uploads to Play internal testing, and redeploys the web version.

**Track:** Internal testing. It's for up to 100 invited people, and releases appear within minutes with no review wait. Your developer account already exists, so skip straight to step 1.

---

## 0. Signing key (required, one time)
In GitHub, go to **Settings → Secrets and variables → Actions → New repository secret** (https://github.com/lalli87/lantern-reader/settings/secrets/actions/new) and add both values from `github-secrets.txt`:
- `LANTERN_KEYSTORE_PASSWORD`
- `LANTERN_KEYSTORE_BASE64`

**Keep `github-secrets.txt` backed up somewhere safe, such as a password manager.** It's the *upload key*. The same key also signs the APKs from GitHub releases, so phone installs update in place.

## 1. Web version (one time)
In GitHub, go to **Settings → Pages → Build and deployment → Source** and choose **GitHub Actions**.
The site is then at **https://lalli87.github.io/lantern-reader/** after the next push (or run the workflow from the Actions tab).

## 2. Create the app in Play Console
**Create app** → Name **Lantern Reader** · Default language **English (United States)** · **App** · **Free** → accept the declarations → **Create app**.

## 3. First release (manual, once)
1. Go to **Test and release → Testing → Internal testing → Create new release**.
2. Under **App signing**, choose **Use Google-generated key**.
3. Upload **`lantern-reader.aab`** from the latest release: https://github.com/lalli87/lantern-reader/releases
4. Click **Next → Save → Roll out to internal testing**.
5. On the **Testers** tab, add your email list (you can reuse the Bolo Notes list), then **Save**.
6. Open the **Join on the web** link on your phone, tap **Accept**, then install from Play.

> The Play build is signed by Google, so it can't update over an APK you installed by hand. Make a backup in the app first (Settings → Back up library), uninstall the hand-installed copy, install from Play, then restore.

## 4. App content (Policy → App content)
| Item | Answer |
|---|---|
| Privacy policy | https://github.com/lalli87/lantern-reader/blob/main/PRIVACY.md |
| App access | All functionality available without special access |
| Ads | No ads |
| Content rating | Fill in the questionnaire. Category: Reference/Utility. The app includes a web browser, so answer **Yes** to "unrestricted internet access"; everything else is No. |
| Target audience | 18+ (or 13+) |
| Data safety | **No data collected.** Text is sent to Google or Anthropic only when the user adds their own API key and uses a cloud voice or translation. It goes straight from the device to that service and the developer never receives it. Data is encrypted in transit: Yes. |
| **Foreground service permissions** | **Media playback.** Description: "The user taps Listen to have a book read aloud. A media-playback foreground service with a visible notification keeps narration playing when the screen is off, with lock-screen and Bluetooth controls, until the user pauses or stops it." Video: a 30-second screen recording (start Listen → lock the screen → narration continues → unlock → pause from the notification), uploaded to YouTube as **Unlisted**. |
| Government / Financial / Health / News | No |

Store listing text and graphics are in `store/` (`listing.md`, `icon-512.png`, `feature-graphic-1024x500.png`). Take phone screenshots of the library, the reader and the narration panel using your own books. Don't show third-party websites.

## 5. Automatic uploads from GitHub (one time)
You can reuse the Google Cloud project and service account you made for Bolo Notes:
1. In **Play Console → Users and permissions**, open the existing `bolo-ci@…` service account. Under **App permissions**, add **Lantern Reader** with **Release apps to testing tracks**, then **Save**.
2. In GitHub, add the repository secret **`PLAY_SERVICE_ACCOUNT_JSON`** with the same JSON contents you used for Bolo Notes.

**If the upload says *"Only releases with status draft may be created on draft app"*:** finish step 4, or temporarily add the repository *variable* `PLAY_STATUS` = `draft`.

## Going public later (optional)
Run a **Closed testing** track with 12+ testers for 14 days, then apply for production and set the repository variable `PLAY_TRACK` to `production`.
