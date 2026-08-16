# Changelog

All notable user-facing changes to this plugin. Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## v1.12 — Smarter Refresh

### Changed

- The list now refreshes immediately after you add, complete, edit, or delete a task, not just on a timer.
- Polling is now 2 minutes while the popup's open, 20 minutes in the background while it's closed (previously 5 and 15, and the two could overlap).

### Fixed

- A task whose completion actually failed (bad network, etc.) could still silently disappear from the list a moment later, as if it had succeeded. It now correctly stays put and shows the error.

## v1.11 — Overdue/Today split

### Added

- The Today view now splits into separate **Overdue** and **Today** sections instead of one combined list.

### Changed

- The empty-list message now reads differently per view ("Inbox is empty.", "No tasks yet.", "No tasks match this filter.") instead of always saying "Nothing due."

## v1.10 — Keyboard-navigable Settings

### Added

- Settings is now fully operable without a mouse — `Tab`/`Shift+Tab` and the arrow keys walk every control in order.
- `t` inside Settings opens Todoist in your browser.

### Fixed

- `Escape` now actually backs out of the token and filter fields.
- The **General** and **Advanced** Settings sections no longer overflow/truncate their button labels.

## v1.9 – v1.9.3 — Priority colors, popup spacing

### Added

- Tasks are now color-coded by Todoist priority (p1 red, p2 yellow, p3 blue, p4 default).

### Fixed

- The bar pill now holds a fixed width regardless of task count, so the popup's anchor point doesn't shift as the count's digit-length changes.
- More breathing room around the popup's edges — the quick-add field and view tabs no longer feel cramped against the border.

## v1.8 — Fixed popup size

### Added

- **Settings → Advanced**: adjustable popup width/height, persisted.

### Fixed

- The popup no longer resizes itself around the current task list — it's a fixed size now, and content that doesn't fit scrolls instead.

## v1.7 — Settings reorganized

### Added

- Settings reorganized into clearly labeled sections: **Account**, **Default filter**, **Keyboard shortcut**, **General**.
- **Refresh now** and **Keyboard shortcuts** buttons in Settings, with real "Refreshing…" feedback.

### Fixed

- The `?` shortcuts overlay no longer runs text past its border.
- Removed the bare header refresh/help icons, which gave no feedback when clicked — same actions are still available via Settings or their shortcuts.

## v1.6 – v1.6.1 — Overflow fix, shortcuts help

### Added

- `?` toggles a keyboard-shortcuts cheat-sheet overlay.

### Changed

- Dropped the spinning-icon animation on the Add button while a task is being created.

### Fixed

- The All view no longer bleeds content past the popup's rounded border with a long task list.
- `Enter` on a task now closes the panel after opening it in the browser, instead of leaving it open.

## v1.5 — Single-key view switching

### Added

- `t`/`i`/`a` jump straight to the Today/Inbox/All view; `p` toggles Settings.

### Fixed

- `Escape` while the Add-a-task box has focus now correctly just leaves the box, instead of doing nothing.

## v1.4 — Task actions

### Added

- Completing a task now strikes it through and dims it briefly before it disappears, instead of vanishing instantly.
- `Enter` opens the selected task on the Todoist website; `Space` completes it.
- `e` edits the selected task's title in place.

## v1.3 — Quick Add parser, delete

### Added

- Quick-add now uses Todoist's own Quick Add parser — `p1`–`p4`, `#Project`, `@label`, and natural-language dates all work like typing into Todoist itself.
- `q` jumps into the quick-add box; `x` deletes the selected task (with confirmation).

### Fixed

- The quick-add box no longer steals keyboard focus on every open, which had been silently blocking the arrow/Tab/`r` shortcuts.

## v1.2 — Full keyboard control

### Added

- Full keyboard control of the task list: `Tab`/`Shift+Tab` cycles views, arrow keys/`j`/`k` move the selection, `Enter`/`Space` completes, `r` refreshes.
- Visual redesign — icon + title, active-view subtitle, segmented view tabs.

### Changed

- The popup now drops directly below its bar icon instead of centering on the whole bar.

## v1.1 — Initial release

### Added

- Today/Overdue, Inbox, and All quick-view tabs.
- Custom Todoist filter field.
- Optional global keyboard shortcut to toggle the panel, safely applied to `bindings.lua` (backed up, with automatic rollback on error).
