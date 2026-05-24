# LRB Reader — Roadmap

Items captured for later. Not committed to; pick up when there is a reason.

### Known bugs
- **Cross-tab state inconsistency.** Marking or unmarking an article in
  one tab does not always reliably update the same article when it is
  shown in another tab (e.g. toolbar archive icon, page link styling
  via injected JS, issue list count). Symptom: "sometimes shows as
  archived and sometimes not." Suspected cause: a combination of
  SwiftUI deferring body re-evaluation for off-screen tabs and the
  JS re-inject only firing on detected changes to the read-URL set.
  An "always re-inject on update" workaround made things worse
  (likely visual flicker or thrash). Needs deeper investigation —
  probably either a forced refresh on tab-becoming-visible, or a
  more reliable change signal that does not depend on Set equality.

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

