# LRB Reader

Personal iPad app for reading the London Review of Books. Wraps the LRB
website with an archive browser, bookmarks, and read tracking.

## What's in it

Tabs at the top, left to right (Web is the default on launch):

- **Web** — in-app web view starting at lrb.co.uk. The app opens here
  so the first thing you see is fresh content. Cookies persist inasmuch
  as you can stay signed in to the LRB site.
- **Issues** — per-year archive from 1979 onward; shows remaining-to-read
  counts per issue and per year. Tap an issue to read it (opens within
  the Issues tab). Swipe a row to archive a whole issue at once.
- **Blog** — in-app web view of the LRB blog.
- **Bookmarks** — pages you have saved via the bookmark toolbar
  button. Tap a bookmark to reopen it within the Bookmarks tab.

Each tab manages its own navigation: opening an issue from Issues
stays in Issues, opening a bookmark from Bookmarks stays in Bookmarks,
etc. The back chevron walks the current page's history, and at the
bottom of history pops back to the list.

The reader toolbar offers reload, archive (works on the current
article, or on the whole issue when you are on its table of
contents), bookmark, and share.

Read tracking marks an article (or blog post) as read after 5 seconds
on the page, or immediately if you tap the archive button. Read links
are dimmed and struck through wherever they appear on LRB pages.

Archiving a whole issue displays every article in the issue as read,
without touching individual read marks. The archive action lives in
two places: a swipe action on each row in the Issues tab, and the
toolbar archive button while on an issue's table of contents in
Browse. Unarchiving from the toolbar offers two variants — one that
keeps any per-article reads you had made, and a destructive one that
clears every read mark for the issue.

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

## Known limitations

- **Cross-tab state inconsistency.** When the same article appears in
  more than one tab at once (e.g. open in Web *and* reached via
  Issues), marking or unmarking it in one tab does not always
  reliably refresh the other tab's view of it. Toolbar icon, page
  link styling, and list counts can briefly disagree. Workaround:
  switch tabs again, or reload the page. Tracked in ROADMAP.

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
