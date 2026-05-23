# LRB Reader — Roadmap

## Active (sequence for next iteration)

These are the features being worked on now, in this order. After all four
ship, the app should be usable enough to install and live with on iPad.

1. **iCloud sync** — Bookmarks, reads, articles, and issues currently
   live only on the device they were created on. CloudKit-backed
   SwiftData so state syncs across devices and survives reinstalls.

2. **Share** — Toolbar button in the Browse view that hands the current
   page (URL + title) off to the system share sheet.

3. **Blog tab** — Top-level tab for `https://www.lrb.co.uk/blog/`.
   Similar shape to Issues: list of recent posts, tap to open in
   Browse, read tracking applies.

4. **"New since last" indicators** — On launch, check for new content
   in Issues, Browse, and Blog. Surface unseen items with the standard
   iPad notification badge (the red dot on the tab).

## Later (below the fold)

Captured for reference. Not committed to; revisit after the active
sequence ships.

### From the original requirements
- **Follow authors** — per-author view, "alert me when this author
  publishes" signal
- **Offline reading** — cache article HTML locally for no-network
  reading
- **Periodic check for new issues** — separate from #4 if we want
  proactive checking even when the app isn't opened (would need
  background work, which we've so far avoided)

### Issues-tab polish
- **Publication dates** next to issue numbers ("Vol. 48 No. 9 — 21 May
  2026"). Held off because parsing dates is brittle.
- **"Fetch everything" button** — single action to fetch all years at
  once rather than per-year on expand
- **Background pre-fetching** across years (same idea, automatic)

### Open design questions
- **Back-button glyph** when at the bottom of WebView history with
  return-to-tab fallback. Currently `arrow.uturn.left` (↶); could keep
  `chevron.left` always, or label "Issues ←".

### Quality of life
- **Read history view** — browse the list of articles you've read (we
  track them, but there's no UI to see them)
- **Way to clear or bulk-edit read state** beyond per-article toggling
- **Bookmarks sort/filter** — currently a flat list; could group by
  issue/author, sort by added/title, etc.
