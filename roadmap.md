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

## v1.2 — projects & richer task views (next)

- Browse the user's actual project list (not just Inbox) and filter by any
  of them from a dropdown instead of typing `#ProjectName`.
- Show project name / color as a small tag on each task row when the view
  isn't already scoped to one project.
- Labels: filter by label, show label chips on tasks.
- Sections within a project (if useful once real usage shows a need).

## v1.3 — task editing

- Change a task's due date from the row (quick "today" / "tomorrow" / pick a
  date) instead of only through Todoist itself.
- Set/change priority from the row.
- Delete a task (with confirmation) — currently only "complete" exists.
- Reopen a just-completed task (undo) — Todoist's `/tasks/{id}/reopen`
  endpoint already supports this, just needs UI.
- Edit task content inline.

## v1.4 — comments & subtasks

- Show subtask count / expand subtasks under a parent task.
- Task comments — view count, maybe add one.

## Ideas / not committed

- Multiple Todoist accounts / workspaces.
- Natural-language due date preview while typing in quick-add (Todoist's
  `/tasks/quick` sync-style endpoint parses this server-side; would need a
  different response shape than the current `/tasks` create call).
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
