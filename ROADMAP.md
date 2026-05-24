# LRB Reader — Roadmap

Items captured for later. Not committed to; pick up when there is a reason.

### From the original requirements
- **Follow authors** — per-author view; some kind of "alert me when this
  author publishes" signal
- **Offline reading** — cache article HTML locally for no-network reading
- **Periodic check for new issues** — proactive notification even when the
  app is not open; would need background work, which we have so far avoided

### Reading and tracking
- **"New since last" indicators** — on launch, check Issues and Blog for
  unseen content; surface as red-dot tab badges. Browse needs a separate
  definition since it has no "set" of content to compare against. Deferred
  because it is hard to test without inducing the state.
- **Read history view** — browse the list of articles read (data exists,
  no UI for it)
- **Bulk clear read state for non-archived issues** — bulk mark exists
  (via issue archive), and unarchive offers a "clear all reads"
  variant. No path yet for clearing reads on issues that were never
  archived.
- **Bookmarks sort/filter** — currently a flat list; could group by
  issue/author, sort by added date or title

### Issues-tab polish
- **Publication dates** next to issue numbers ("Vol. 48 No. 9 — 21 May
  2026"). Held off because parsing dates from the page is brittle.
- **"Fetch everything" button** — single action to fetch all years at once
  rather than per-year on expand
- **Background pre-fetching** across years (same idea, automatic)

### Open design questions
- **Back-button glyph** when at the bottom of WebView history with the
  return-to-tab fallback. Currently `arrow.uturn.left` (↶); alternatives
  are keeping `chevron.left` always, or labeling "Issues ←".
