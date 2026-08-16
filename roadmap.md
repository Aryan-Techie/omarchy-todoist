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

## v1.9.2 — shipped

- User confirmed v1.9.1's pill-width fix resolved the position-shift issue.
- New report, with a screenshot: the quick-add row and the Today/Inbox/All
  tab row appeared to overflow past the panel's left edge. Best working
  theory (couldn't reproduce it directly in my own render, same as the
  position-shift investigation): the selected tab's border, drawn by the
  shared `Button` component, can render outside its own bounds depending on
  the active theme's `[controls] selected-border-width` — on a theme with a
  non-zero value this would poke the "Today" tab's highlight slightly past
  the row's left edge, while my own test theme's value happens to be zero
  (or otherwise not exhibit it). Added `clip: true` to both rows regardless
  of exact mechanism, so nothing either row's children render can bleed
  past their bounds — a defensive fix aimed at the *symptom* since the
  precise *cause* couldn't be confirmed empirically this time. Verified no
  regression (all three tabs, quick-add field, and Add button still render
  and lay out correctly) but, like v1.9.1, flagged for the user to confirm
  it actually addresses what they saw.

## v1.9.3 — shipped

- Turned out the "overflow"/"shifting" reports in v1.9.1/v1.9.2 were a
  misread on my part — the user clarified nothing was actually moving; the
  quick-add field and tab row just felt too close to the panel's left edge,
  cramped against the border. Root cause: `KeyboardPanel`'s default padding
  (14px) reads as tight specifically next to a *bordered* control like the
  TextField — two borders sitting close together (the card's and the
  field's own) feel more cramped than the same gap next to plain text does.
  Fixed directly by bumping the panel's own `padding` to 20px, giving every
  edge more breathing room uniformly (not just the left side, and not just
  the quick-add row) rather than special-casing one element.
- Lesson from this whole thread (v1.9 → v1.9.3): "overflowing"/"shifting"
  turned out to mean three *different* things across four reports — a
  content-driven resize (v1.8), an anchor-point shift from the bar pill's
  own width changing (v1.9.1), a possible border render quirk (v1.9.2,
  never confirmed), and finally just "not enough padding" (v1.9.3, the
  actual one). Worth asking "is something moving, or does something look
  too close to an edge" early next time similar wording comes up, rather
  than assuming a dynamic bug from words like "overflow"/"shift" alone.

## v1.10 — keyboard-navigable Settings — shipped

- Settings is now fully operable without a mouse: `Tab`/`Shift+Tab` and the
  arrow keys walk an explicit focus chain across every control (token field,
  Save/Remove token, filter field + Apply, keybind buttons, General and
  Advanced buttons/steppers), skipping any control that's currently disabled
  (a disabled item silently rejects `forceActiveFocus()` in Qt Quick — the
  chain now filters those out itself rather than trying and failing to land
  on them). Focus scrolls the Settings panel into view as it moves.
- `Escape` now actually backs out of the token/filter fields — it previously
  had no effect there because those fields never got the same
  `Keys.onEscapePressed` handler the quick-add field already had.
- New `t` shortcut inside Settings opens Todoist in the browser
  (`xdg-open https://app.todoist.com/app/today`) — deliberately left out of
  the Tab/arrow focus chain, since launching an external app mid-keyboard
  navigation reproducibly stole the panel's window focus; still reachable by
  mouse or `t`.
- **General** and **Advanced** sections both switched from a horizontal `Row`
  (which visibly overflowed and truncated button labels, e.g. "Keybo…") to
  vertical stacks of full-width bordered blocks — General as one button per
  row (Refresh now / Open Todoist / Keyboard shortcuts), Advanced as a
  labeled width block and a labeled height block, each with its own `−`/`+`
  steppers.

## v1.11 — Overdue/Today split, native-widget prep — shipped

- Task-list empty state now reads differently per active view ("Inbox is
  empty.", "No tasks yet.", "No tasks match this filter.") instead of the
  same "Nothing due. You're clear." on every tab, which only made sense for
  Today.
- The Today view's combined `today | overdue` list is now visually split
  into two row-anchored sections, **OVERDUE · N** and **TODAY · N**, each
  with its own separator — same "header attached to the first row of its
  group" pattern the built-in bluetooth panel uses for Paired/Available
  devices. No change to the underlying filter query or sort order: `root
  .tasks` was already sorted due-date-ascending, so overdue and today tasks
  were already contiguous — the split only adds section headers at the
  group boundary, still by due date/time, then priority, then existing
  ordering. Inbox/All/Custom Filter are unaffected and keep their single
  generic header.
- Repo inspected end-to-end (QML architecture, API layer, keyboard handling,
  settings, styling, scripts) ahead of a larger feature batch. Decided
  **against** splitting `Panel.qml` into multiple component files — checked
  the built-in shell first and found bluetooth (1039 lines) and audio (1237
  lines) both stay single-file with inline `component` blocks even past our
  size, so that's the actual convention, not a size-driven split. Also
  investigated the Settings gear icon's Nerd Font dependency (`Style
  .fontFamily` is a user-repointable `monospace` alias, not guaranteed
  Nerd-Font-patched) — no runtime glyph-fallback is buildable in QML without
  C++, and nothing in the built-in shell does this either, so the risk is
  accepted and documented (checklist.md) rather than engineered around.

## v1.12 — Advanced Task Editing — shipped

- `Shift+Q` opens a full editor for the selected task, separate from the
  lightweight `e` inline title-only edit (which is untouched): title,
  priority (**P1**–**P4**), due date/time as one natural-language field
  (same parser Quick Add already uses, plus an explicit **Clear due date**
  button rather than two separate date/time widgets), project (`Ui/Dropdown`),
  and labels (`Ui/MultiSelect`). `Tab`/`Shift+Tab` walks every field,
  `Enter` saves, `Escape` cancels — same explicit focus-chain approach
  Settings already uses, extended with two small focusable proxy items for
  the project/label pickers (Dropdown/MultiSelect don't expose their
  internal focusable trigger for an external `forceActiveFocus()` to land
  on, so the proxy stands in for "the chain's cursor is here" and drives
  the real component's own `hasCursor` visual).
- Verified against the live Todoist OpenAPI spec (not guessed) before
  building: Update Task (`POST /tasks/{id}`) has no `project_id` field —
  moving a task between projects is a separate `POST /tasks/{id}/move`
  call, fired alongside the Update call when needed. `GET /projects` and
  `GET /labels` populate the pickers (fetched once per panel lifetime,
  cached). Clearing a due date has no documented `null`/clear flag on this
  endpoint (unlike `assignee_id`/`duration`, which do) — uses Todoist's
  long-standing `due_string: "no date"` convention instead, same NLP engine
  as everything else due-related in this plugin.
- Only fields actually changed are sent (diffed against the task's original
  values, same "omit to keep unchanged" contract the API already documents
  for every other field). Optimistic local update on save, same pattern as
  the existing complete/delete/inline-title-edit actions; loading state
  ("Saving…", fields disabled) while the save call(s) are in flight; on
  failure the editor stays open with the error shown inline so nothing
  typed is lost.

## v1.13 — projects & richer task views (next)

- Browse the user's actual project list (not just Inbox) and filter by any
  of them from a dropdown instead of typing `#ProjectName`.
- Show project name / color as a small tag on each task row when the view
  isn't already scoped to one project.
- Labels: filter by label, show label chips on tasks.
- Sections within a project (if useful once real usage shows a need).

## v1.14 — more task actions

- Reopen a just-completed task (undo) — Todoist's `/tasks/{id}/reopen`
  endpoint already supports this, just needs UI.
- Mouse-accessible delete (small button on hover) alongside the `x` shortcut.
- Edit description (the advanced editor doesn't cover this yet).

## v1.15 — comments & subtasks

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
