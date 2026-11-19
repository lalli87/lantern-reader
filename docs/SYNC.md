# Google Drive sync

The phone app (`lib/src/drive_sync.dart`) and the web version (`web-app/sync.mjs`) share one format, so a
book or a reading position saved on one shows up on the other. Both sign in with the same Google Cloud
OAuth web client ID and ask only for the `drive.file` scope: Lantern sees just the files it created.

## Drive layout

Folder **Lantern Reader** in My Drive (`appProperties.lantern = "root"`), holding:

| File | appProperties | Content |
| --- | --- | --- |
| `<title>.lantern.json.gz` | `lantern=book`, `sid`, `sig` | gzip JSON book (below) |
| `progress-<device id>.json` | `lantern=progress`, `dev` | JSON progress of one device (below) |

Each device writes only its own progress file, so two devices never overwrite each other.

Book (`v` = 1):

```json
{"v":1,"sid":"…","title":"…","author":"…","format":"PDF","addedAt":1700000000000,
 "chapters":[{"title":"…","paras":["# Heading","Paragraph", "…"]}]}
```

Paragraphs follow the app's convention: one string per paragraph, headings start with `#`, `##` or `###`.

Progress:

```json
{"v":1,"device":"Phone","at":1700000000000,
 "books":{"<sid>":{"ch":3,"para":17,"at":1700000000000,"title":"…"}},
 "deleted":{"<sid>":1700000000000}}
```

## Identity and change detection

- `sid`: random id given to a book the first time it syncs; stays with the book on every device.
- `sig`: `"<chapter count>:<total characters>"`, where total characters is the sum over chapters of
  `paras.join("\n").length` (equals the phone's `chapters.char_count` sum). A device remembers the `sig`
  it last uploaded or downloaded for each book.

## One sync run

1. Find or create the folder; list its files.
2. `deleted` = union of the `deleted` maps of all progress files plus this device's own pending deletions.
3. Each local book: give it a `sid` if it has none.
   - `sid` in `deleted` → delete the local book.
   - On Drive: local `sig` ≠ remembered → upload (local wins); else remote `sig` ≠ remembered → download
     and replace the chapters (position kept); else nothing.
   - Not on Drive → upload (also when it was synced before: nothing is lost if someone removed the file).
4. Each Drive book not on this device and not deleted → download and add.
5. Positions: for each `sid`, the entry with the newest `at` over all progress files wins if it is newer
   than the local position time; it is applied with that same time (so it does not bounce back).
6. Pending local deletions → move those Drive files to the trash.
7. Write this device's progress file (all local positions + `deleted`).

When to run: app start / page load, coming back to the app, leaving a book, after import or delete, every
few minutes while reading, and "Sync now". Not synced (yet): original PDF files and their page maps,
bookmarks, highlights, translations, settings and API keys.
