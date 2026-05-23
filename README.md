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

Open `LRBReader.swiftpm/Package.swift` in Xcode and run on the iPad
simulator, or open the package on iPad in Swift Playgrounds and tap
Run.

Installing on a real iPad signed with a free Apple ID gives a 7-day
signing expiry; the paid Apple Developer Program ($99/yr) extends that
to a year.
