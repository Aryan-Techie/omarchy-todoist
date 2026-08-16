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

## v1.6 — projects & richer task views (next)

- Browse the user's actual project list (not just Inbox) and filter by any
  of them from a dropdown instead of typing `#ProjectName`.
- Show project name / color as a small tag on each task row when the view
  isn't already scoped to one project.
- Labels: filter by label, show label chips on tasks.
- Sections within a project (if useful once real usage shows a need).

## v1.7 — more task actions

- Change a task's due date from the row (quick "today" / "tomorrow" / pick a
  date) instead of only through Todoist itself.
- Set/change priority from the row.
- Reopen a just-completed task (undo) — Todoist's `/tasks/{id}/reopen`
  endpoint already supports this, just needs UI.
- Mouse-accessible delete (small button on hover) alongside the `x` shortcut.
- Edit description, not just title.

## v1.8 — comments & subtasks

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
