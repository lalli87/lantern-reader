# Lantern Reader

An offline reader and narrator for web novels and e-books. Built with Flutter, so the same code
runs on Android now and can be built for iPhone later.

## What it does

- **Web tab**: a text-only browser. Open a chapter, tap **Save chapter**, and the story text is added
  to a book as the next chapter. **Save & next** saves and moves to the following chapter.
- **Library**: reading lists (Reading now, Favourites, To read, Finished, Trash), shelves, grouping by
  author / series / format, three layouts, sorting and search. Imports EPUB, TXT, Markdown, HTML,
  FB2, DOCX and ODT.
- **Reader**: five colour themes, bundled and user fonts, size, weight, line spacing, margins,
  justification, scrolling or page turning, bookmarks, colour highlights with notes, a glossary
  (words, characters, terms) marked in the text, find, brightness swipe, tap corners.
- **Narration**: reads aloud with any speech engine installed on the phone (Samsung, Google, …),
  keeps going with the screen off, and shows up on the lock screen, Bluetooth and car controls.
  Speed 0.1×–4× remembered per voice, sleep timer, pronunciation fixes, auto-advance.
- **Audio files**: renders chapters to WAV with the phone's voice or a Gemini voice.
- **AI translation** of chapters or selections with a Gemini or Claude API key.
- **Natural voices**: Google Cloud (Chirp 3 HD, Neural2, Studio, WaveNet) and Gemini, for live narration
  (read ahead and cached) and for audio files: MP3 with Google, M4A with Gemini or phone voices.
- **Export** to EPUB or plain text; **backup / restore** of the whole library.
- **Web version** (`web-app/`): library, reader, EPUB / PDF / TXT / MD / HTML import, narration with
  browser / Google / Gemini voices, MP3 creation, sleep timer. Deployed to https://lalli87.github.io/lantern-reader/
  PDFs go through the same Dart layout code as the phone (`tool/web_pdf.dart` → `web-app/pdfbook.js`,
  rebuilt by CI) with text from pdf.js.
- **Scanned PDFs**: text recognition (OCR) when a PDF has no text inside: Google ML Kit on the phone (offline),
  Tesseract.js in the web version (downloads from jsDelivr on first use). Words go through the same layout code.
- **Google Drive sync** of books and reading positions between the phone and the web version
  (`docs/SYNC.md`; one-time Google Cloud setup in `docs/GOOGLE_SIGNIN_SETUP.md`).

## Releases

Every push to `main` runs `.github/workflows/build.yml`: tests, signed APK + AAB, a GitHub release,
upload to Google Play internal testing, and deployment of the web version. See `PLAY_SETUP.md`.

## Build locally

```
flutter pub get
flutter test
flutter build apk --release --target-platform android-arm64
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

### Signing key — keep it

The signing key is not in the repository. CI restores it from the `LANTERN_KEYSTORE_*` secrets. For a
local release build, put `lantern-release.jks` in `android/app/` and a `key.properties` in `android/`
(both are git-ignored). Values are in `github-secrets.txt`, kept outside the repo.

### iPhone

`ios/` is set up for background audio. Building needs a Mac with Xcode:
`flutter build ios`. Choosing the speech engine is Android-only; on iPhone the system voices are used.

## Layout

```
lib/main.dart                app start, tab shell
lib/src/db.dart              SQLite storage
lib/src/models.dart          data classes
lib/src/settings.dart        preferences, reading themes
lib/src/library.dart         library screen
lib/src/book_detail.dart     book details, chapter manager, audio export screen
lib/src/browser.dart         web tab, page text extraction, save sheet
lib/src/reader.dart          reader screen
lib/src/reader_widgets.dart  paragraph rendering, text sheet, contents, highlight and glossary editors
lib/src/pagination.dart      page layout for page-turn mode
lib/src/narrator.dart        text-to-speech playback and media session
lib/src/narration_ui.dart    mini player, narration panel, voice picker
lib/src/importers.dart       EPUB / TXT / MD / HTML / FB2 / DOCX / ODT import
lib/src/pdf_import.dart      PDF import (pdfium)
lib/src/cloud_tts.dart       Google Cloud and Gemini voices, audio cache
lib/src/epub_export.dart     EPUB and text export
lib/src/exports.dart         file sharing, audio rendering, backup and restore
lib/src/ai.dart              translation and Gemini speech
lib/src/notes.dart           highlights, bookmarks and glossary across books
lib/src/settings_screen.dart settings
test/                        logic tests and screen tests
web-app/                     web version (single page; pdfimport.mjs + pdfbook.js for PDFs)
tool/web_pdf.dart            entry point compiled to web-app/pdfbook.js
lib/src/pdf_book.dart        PDF pages → paragraphs and chapters (pure Dart, shared with the web)
lib/src/pdf_layout.dart      column / reading-order layout (pure Dart, shared with the web)
```

## Third-party

Bundled fonts (Literata, Atkinson Hyperlegible, JetBrains Mono) are under the SIL Open Font License 1.1.
Page text detection uses Mozilla Readability (Apache License 2.0). The web version bundles JSZip (MIT)
and lamejs (LGPL-3.0), pdf.js (Apache License 2.0, `web-app/pdfjs/`) and Tesseract.js (Apache License 2.0, `web-app/ocr/`). The phone app
uses Google ML Kit text recognition. See `assets/` and `web-app/`.

All rights reserved. The source is published for viewing; no licence is granted to copy or redistribute it.
