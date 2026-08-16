# Roadmap

Where this plugin is headed. See [checklist.md](checklist.md) for the
concrete pre-publish gate — this file is about scope and direction, not
launch-readiness.

## v1.1 — shipped

- Today/Overdue, Inbox, and All quick-view tabs.
- Custom Todoist filter field for anything else.
- Optional global keyboard shortcut (default Ctrl+Super+Y, user-recordable)
  to toggle the panel, applied safely to `bindings.lua` (backup + reload +
  auto-rollback).

## v1.2 — shipped

- Panel now drops directly below its bar icon instead of centering on the
  bar (`centerOnBar: false`).
- Full keyboard control: two-stage `Escape` (Settings → task list → close),
  `Tab`/`Shift+Tab` cycles the quick-view tabs, `↑`/`↓`/`j`/`k` moves a
  selection cursor through the task list, `Enter`/`Space` completes the
  selected task, `r` refreshes.
- Visual pass inspired by the bundled Agent (Claude Code) panel: icon next
  to the title, a small-caps subtitle line showing the active view + task
  count, a tightened segmented-control look for the Today/Inbox/All tabs,
  and a `PanelSectionHeader` label above the list — reusing the same shared
  Ui components the rest of the shell's panels use rather than one-off
  styling.

## v1.3 — shipped

- Fixed a real bug: the quick-add field grabbed keyboard focus by default on
  every open, which silently swallowed all of v1.2's new shortcuts (arrows,
  Tab, r) since they're suspended whenever a text field has focus. Panel now
  only auto-focuses a field when Settings needs the token typed immediately;
  otherwise focus stays on the general key handler.
- Quick-add now goes through Todoist's own Quick Add parser (`POST
  /tasks/quick`) instead of a plain create call — `p1`–`p4` priority,
  `#Project`, `@label`, and natural-language due dates all work exactly like
  typing into Todoist itself. A bare task with no date hint gets " today"
  appended so it defaults to due today instead of no due date.
- `q` jumps focus straight into the quick-add box.
- `x` deletes the selected task via `DELETE /tasks/{id}`, with a confirm
  dialog (`Ui/ConfirmDialog`) first since delete isn't reversible from here.

## v1.4 — shipped

- Completing a task now shows feedback instead of an instant vanish: the row
  strikes through and dims immediately, then actually leaves the list ~700ms
  later. The API close call itself still fires right away — only the row's
  disappearance is delayed.
- `Enter` opens the selected task on the Todoist website
  (`https://app.todoist.com/app/task/{id}` via `xdg-open`); `Space` still
  completes it. (PanelKeyCatcher fires both `returnRequested` and
  `activateRequested` for the same Enter press — a `suppressNextActivate`
  flag stops the completion half from also firing.)
- `e` edits the selected task's title in place (`POST /tasks/{id}`),
  `Enter` to save, `Escape` to cancel.

## v1.5 — shipped

- Single-key view switching: `t` (Today), `i` (Inbox), `a` (All), `p`
  (toggle Settings) — alongside the existing `Tab`/`Shift+Tab` cycling.
- `Escape` while the Add-a-task box has focus just leaves the box (back to
  normal keyboard nav) instead of doing nothing — it was falling through to
  the panel's own Escape handling, which is suspended whenever any text
  field has focus, so it previously had no visible effect at all.

## v1.6 — shipped

- Fixed a real overflow bug reported with a screenshot: on the All view with
  enough tasks, content could visually bleed past the card's rounded border
  instead of staying clipped. Root cause was the "Loading…" row rendering
  *underneath an already-populated list* during a background/periodic
  refresh (it only ever should have shown for the initial empty-list fetch)
  — that extra row was enough to push total content past the panel's height
  budget. Fixed the immediate cause (Loading now only shows when the list is
  actually empty) and added a `clip: true` safety net on the panel's own key
  handler as defense in depth, so nothing can bleed past the card regardless
  of cause.
- `Enter` on a task now also closes the panel after opening it in the
  browser — previously it opened the tab but left the panel sitting open.
- `?` (or the new "?" button in the header) toggles a keyboard-shortcuts
  cheat-sheet overlay.

## v1.6.1 — shipped

- Dropped the spinning-icon animation on the Add button while a task is
  being created — reported as feeling "weird." Replaced with a plain
  `Adding…` text label instead; no rotation anywhere in the plugin now.

## v1.7 — shipped

- Fixed a real overflow bug in the `?` shortcuts overlay, also reported with
  a screenshot: text ran right up against (and past) the card's border. Root
  cause was `BorderSurface.padding` not automatically applying to children —
  its inset has to be applied by hand via `contentTopInset`/etc., same as
  `Ui/ConfirmDialog.qml` already does; the overlay just wasn't doing it.
  Fixed by wrapping the content in an inset-margined `Item`, matching that
  proven pattern, and widened the card slightly (300px → 340px) so the
  longest shortcut line wraps comfortably instead of running edge to edge.
- Removed the header's ↻ refresh and "?" help icons — reported as feeling
  unresponsive/confusing sitting bare in the header with no feedback when
  clicked. Refresh and the shortcuts overlay are both still fully available
  (`r` / `?`, or now from Settings), just not as ambiguous bare icons up top.
- Settings reorganized into clearly labeled sections (**Account**, **Default
  filter**, **Keyboard shortcut**, **General**) using `PanelSectionHeader`,
  matching the visual language used elsewhere in the panel. The new
  **General** section has explicit **Refresh now** (shows "Refreshing…"
  while in flight — real, undeniable feedback instead of a silent icon) and
  **Keyboard shortcuts** buttons. The filter field also gained an explicit
  **Apply** button next to it instead of Enter-only.
- Header subtitle now shows "LOADING…" during the very first fetch on an
  empty list (background refreshes of an already-populated list stay quiet,
  matching the earlier overflow fix's reasoning).

## v1.8 — shipped

- Popup is now a **fixed size** (`panelWidth`/`panelHeight`, default 340×480)
  instead of resizing itself around `mainColumn.implicitHeight`. Sizing the
  window off live content was the actual root cause behind both overflow
  reports (All view, `?` overlay) — a fixed size scrolls content inside the
  Flickable instead of stretching/shrinking the window around it.
- New **Settings → Advanced** section: `−`/`+` steppers for width and
  height (20px steps, clamped 260–700 × 240–800), persisted like every other
  setting. Pattern lifted directly from `io.github.weedwhitesandwine.omascratch`'s
  own working "Size" steppers (`cardWidth`/`cardHeight` + `setCardWidth`/
  `setCardHeight`), adapted from its `PanelWindow.implicitWidth/Height` to
  this plugin's `KeyboardPanel.contentWidth/Height`.
- Settings gear icon switched from the plain Unicode `⚙` to omascratch's
  Nerd Font glyph (`󰒓`) for visual consistency with the rest of the bar.

## v1.9 — shipped

- Task rows are now color-coded by Todoist priority: **p1 red (`#eb5757`),
  p2 yellow (`#f2b84b`), p3 blue (`#4a90d2`), p4 normal** (default text
  color). Applied to both the content text and the checkbox icon.
- Investigated a further "still resizing" report with two more screenshots.
  Reproduced it directly and empirically this time — opened the real panel,
  used `wtype` to switch Today → All programmatically, and diffed
  screenshots pixel-for-pixel (`grim`) rather than relying on visual
  comparison alone. **Result: the card's outer border sits at the exact
  same coordinates in both views** — the v1.8 fixed-size fix genuinely
  works. What reads as "resizing" is that a sparse 6-task Today view leaves
  visible empty space at the bottom of the same fixed box, while a dense
  26-task All view fills it edge to edge — the box doesn't change, only how
  full it looks. No code change from this investigation; documented here so
  it isn't re-litigated blindly without new evidence next time it comes up.

## v1.9.1 — shipped

- Found and fixed a real, plugin-owned contributor to the position-shift
  reports: the bar pill's own width changes with the task count's
  digit-length (`"✓ 7"` vs `"✓ 15"`), and since the popup is centered under
  that pill (`x = anchorScreenPos.x + anchorW/2 - contentWidth/2` inside the
  shared `Ui/KeyboardPanel.qml`), a wider/narrower pill shifts the popup's
  center point even though the popup's own size never changes. Fixed by
  giving the bar `WidgetButton` a `fixedWidth` sized (via `TextMetrics`) to
  fit the widest realistic label (`"✓ 999"`), so the pill's width — and with
  it the anchor point — never moves regardless of count.
- Two more rounds of user-reported screenshots investigated with the same
  `grim` + `wtype` pixel-diffing method as v1.9, this time specifically
  reproducing Today↔Inbox switches with the panel left open the whole
  time (matching the user's confirmed repro steps exactly) — still could
  not reproduce the full magnitude of shift shown in their screenshots on
  this build, before or after the pill-width fix above. The pill-width fix
  is real and worth keeping regardless, but may not be the whole story;
  flagged to the user to re-test and report whether it's fully resolved or
  only partially.
- Considered (but did not implement) freezing the popup's position entirely
  by snapshotting it once on open, ignoring the shared `KeyboardPanel`'s
  live anchor-tracking (`TransformWatcher`) after that. Not done because it
  would require bypassing/reimplementing part of a shared system component
  this plugin doesn't own — meaningfully more risk than the targeted
  pill-width fix, and not yet justified without confirming it's still
  needed after this fix lands.

## v1.10 — projects & richer task views (next)

- Browse the user's actual project list (not just Inbox) and filter by any
  of them from a dropdown instead of typing `#ProjectName`.
- Show project name / color as a small tag on each task row when the view
  isn't already scoped to one project.
- Labels: filter by label, show label chips on tasks.
- Sections within a project (if useful once real usage shows a need).

## v1.11 — more task actions

- Change a task's due date from the row (quick "today" / "tomorrow" / pick a
  date) instead of only through Todoist itself.
- Set/change priority from the row.
- Reopen a just-completed task (undo) — Todoist's `/tasks/{id}/reopen`
  endpoint already supports this, just needs UI.
- Mouse-accessible delete (small button on hover) alongside the `x` shortcut.
- Edit description, not just title.

## v1.12 — comments & subtasks

- Show subtask count / expand subtasks under a parent task.
- Task comments — view count, maybe add one.

## Ideas / not committed

- Multiple Todoist accounts / workspaces.
- Live preview of what Quick Add parsed (date/project/priority) before
  submitting — `/tasks/quick` supports a `meta: true` flag that returns the
  parse result; would need a debounced preview call as the user types.
- Drag-to-reorder or drag-to-reschedule.
- Notification when a task becomes overdue.
- Completed-tasks view (`GET /tasks/completed`) — separate endpoint/pagination
  model from active tasks, bigger lift than it looks.
- A second, dedicated `panel` kind (like omascratch) so the task list can be
  summoned independently of the bar icon via its own keybind route, instead
  of always toggling through the bar-widget's `open()`. Not needed unless a
  concrete use case shows up — the current single `bar-widget` kind (matching
  the built-in clock's contract) covers everything so far.

## Explicitly out of scope

- Rewiring the global "close window" keybind (SUPER+Q on this machine) to
  close the Todoist panel first. Discussed 2026-08-16: it would mean
  hijacking a system-wide keybind that affects every app, not just this
  plugin, for a problem Escape and the dedicated toggle shortcut already
  solve. Revisit only if Omarchy itself ships a generic "close active panel"
  primitive that plugins can hook into instead of each one reinventing it.
