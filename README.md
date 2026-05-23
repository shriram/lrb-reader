# LRB Reader

Personal iPad app for reading the London Review of Books. Wraps the LRB
website with an archive browser, bookmarks, and read tracking.

## What's in it

Three tabs:

- **Issues** — per-year archive from 1979 onward; shows unread counts
  per issue and per year
- **Browse** — in-app web view of lrb.co.uk; toolbar buttons for
  bookmark and mark-as-read
- **Bookmarks** — saved pages

Read tracking marks an article read after 5 seconds on the page, or
immediately if you tap the archive button. Read links are dimmed and
struck through wherever they appear on LRB pages.

## Depends on

- Xcode 17+ on macOS, or Swift Playgrounds 4+ on iPad, to build
- iPadOS 17+ to run
- An LRB subscription — you sign in to lrb.co.uk inside the app once;
  the cookie persists

## Assumes

- **iCloud Backup is enabled.** All state lives in a local SQLite
  database; iOS auto-includes that in nightly iCloud Backup. If
  iCloud Backup is off, the data is ephemeral — uninstall or device
  loss wipes it. There is no in-app export. Check at: Settings → your
  name → iCloud → iCloud Backup.
- **No live cross-device sync.** State propagates only via the backup
  → restore cycle.

## Running it

**On the iPad itself (recommended — free, no expiry):**

1. Get the `LRBReader.swiftpm` package onto your iPad (e.g. via
   iCloud Drive, then open from the Files app)
2. Tap to open it in **Swift Playgrounds**
3. Tap **Run** (▶) — the app launches full-screen

The app runs inside Swift Playgrounds' sandbox. Swift Playgrounds is
itself an App Store app, so it never expires and requires no Apple
Developer Program enrollment. The only friction is that you launch
the app through Swift Playgrounds rather than from the home screen.

**On the Mac simulator (for development):**

Open `LRBReader.swiftpm/Package.swift` in Xcode and run on the iPad
simulator.

**Installing as a standalone home-screen app (optional):**

Going this route requires Apple's signing:

- Free Apple ID via Xcode: 7-day expiry per signing (rebuild weekly)
- Paid Apple Developer Program ($99/yr): 1-year expiry per signing

This is *not* required for normal use — the Swift Playgrounds path
above covers that.
