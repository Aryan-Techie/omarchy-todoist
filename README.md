# Todoist for Omarchy

A [Todoist](https://www.todoist.com/) bar widget for [Omarchy](https://omarchy.org/). The
bar shows how many tasks are due today or overdue; click it for a popup with
the full list, a checkbox to complete each task, and a box to quickly add new
ones — all without leaving the keyboard.

## Features

- Bar pill shows a checkmark plus your due/overdue task count (just a
  checkmark when the list is clear).
- Panel lists matching tasks, sorted by due date then priority, with the
  overdue ones picked out in red.
- Click the circle next to a task to mark it complete (updates instantly,
  syncs to Todoist in the background).
- Quick-add box uses Todoist's own Quick Add parser — `p1`–`p4` priority,
  `#Project`, `@label`, and natural-language due dates (`tomorrow at 5pm`,
  `next Monday`) all work exactly like typing into Todoist itself. A bare
  task with no date in it (`Buy milk`) defaults to due **today**.
- **Today / Inbox / All** quick-view tabs above the list, plus a custom
  [Todoist filter](https://www.todoist.com/help/articles/introduction-to-filters-V98wIH)
  field in Settings for anything more specific (defaults to `today | overdue`).
- Settings view (gear icon) to paste your API token and manage the above.
- Optional global keyboard shortcut (**Ctrl+Super+Y** by default, or record
  your own) to toggle the panel from anywhere — no mouse required.
- Refreshes automatically every 5 minutes while open, every 15 minutes in the
  background, and immediately whenever you open the popup.

## Install

```
omarchy plugin add https://github.com/aryan-techie/omarchy-todoist.git --enable
```

Add the bar icon (skip this if `--enable` already placed it):

```
omarchy bar put io.github.aryan-techie.todoist --section right
```

## Setup

1. Open the panel (click the bar icon) — with no token saved it opens
   straight to Settings.
2. In Todoist, go to **Settings → Integrations → Developer** and copy your
   personal API token.
3. Paste it into the field and click **Save token**.

That's it — the panel switches to your task list and the bar starts showing
your count.

The panel drops right below its bar icon (not centered on the bar).

## Usage

- **Open/close**: click the bar icon, your keyboard shortcut (see below), or
  `omarchy-shell shell toggle io.github.aryan-techie.todoist`.
- Click **Today**, **Inbox**, or **All** to switch views.
- Click a task's circle to mark it complete.
- Type in the box at the top of the list and press Enter (or click **Add**)
  to create a task — see Quick Add syntax above (`p1`, `#Project`, dates).
- The ↻ icon refreshes the list; the ⚙ icon opens Settings, where you can
  change the filter, set a keyboard shortcut, or remove your token.
- Middle-click the bar icon to refresh without opening the panel.

### Keyboard controls

The whole panel is operable without a mouse:

| Key | Action |
| --- | --- |
| `Escape` | Back out of Settings to the task list; press again to close the panel. While the Add-a-task box has focus, just leaves the box instead |
| `Tab` / `Shift+Tab` | Cycle Today → Inbox → All (switches to the next bar panel instead, while Settings is open) |
| `t` / `i` / `a` | Jump straight to the Today, Inbox, or All view |
| `p` | Toggle Settings open/closed |
| `↑`/`↓` or `k`/`j` | Move the selection up/down the task list |
| `Enter` | Open the selected task on the Todoist website, then close the panel |
| `Space` | Complete the selected task |
| `e` | Edit the selected task's title in place |
| `x` | Delete the selected task (asks for confirmation first) |
| `q` | Jump into the Add-a-task box |
| `r` | Refresh |
| `?` | Toggle a shortcuts cheat-sheet overlay (also the "?" button in the header) |

Completing a task strikes it through and dims it for a moment before it
disappears from the list, so the click reads as "done" rather than "vanished."

Typing in the token, filter, or quick-add fields (or recording a shortcut)
temporarily suspends these so normal typing works. `x` for delete matches
this shell's own convention (see `Ui/PanelKeyCatcher.qml`) rather than the
physical Delete key, which has no printable character for a panel's key
handler to see.

### Keyboard shortcut

In Settings, click **Ctrl+Super+Y** to use that shortcut, or **Record
custom…** to press your own combo (any number of Super/Ctrl/Alt/Shift plus
one key). Applying it edits `~/.config/hypr/bindings.lua` — the file is
backed up first, Hyprland is reloaded, and if the reload reports any config
error the backup is restored automatically. **Remove** takes the line back
out the same safe way. No shortcut is set until you explicitly choose one
here; the plugin never touches your Hyprland config on its own.

Note: pressing the shortcut again while the panel is open closes it — that's
the built-in way to close the panel from the keyboard. Your existing
"close window" keybind is untouched and still closes whatever app window is
focused, not this panel (that's a Hyprland layer-shell limitation shared by
every panel in the shell, not something specific to Todoist).

## External dependencies and system-level modifications

This plugin runs `curl`, `mkdir`, `chmod`, `bash`, `awk`, `cp`, `xdg-open`
(only when you press Enter on a task, to open it in your browser), and
(only for the optional keyboard shortcut) `hyprctl` via Quickshell's
`Process` — all standard on any Omarchy install, no extra packages required.
`curl` is the only thing that talks to the network; every request goes
straight to `https://api.todoist.com/api/v1/` with your token in an
`Authorization: Bearer` header. Nothing else is contacted, and nothing runs
with elevated
privileges.

**The only system file this plugin can modify is
`~/.config/hypr/bindings.lua`, and only if you set a keyboard shortcut from
Settings.** `set-keybind.sh` then:

1. Backs up `bindings.lua` to `bindings.lua.bak.<unix-timestamp>` (not
   auto-deleted — clean these up yourself periodically if you change the
   shortcut often).
2. Adds or rewrites the one `o.bind(...)` line that toggles Todoist,
   identified by matching the exact `omarchy-shell shell toggle
   io.github.aryan-techie.todoist` command string — no other line is ever
   touched.
3. Runs `hyprctl reload` and checks `hyprctl configerrors`.
4. If the reload reports any config error, restores the backup and reloads
   again — a bad shortcut can't leave Hyprland in a broken state.

This never happens automatically — only when you click **Ctrl+Super+Y**,
**Record custom…** + **Apply**, or **Remove** in Settings. Adding/removing
the bar icon itself only touches your own `~/.config/omarchy/shell.json` bar
layout, the same as any other bar widget you add or remove through
`omarchy bar`.

## State files

- `~/.local/state/omarchy/io.github.aryan-techie.todoist/settings.json` —
  your Todoist API token, filter, quick-view, and keyboard shortcut. Created
  on first save; the file is `chmod 600`'d right after writing since it holds
  a secret. Delete it (or use **Remove token** in Settings) to disconnect the
  plugin from your account.
- `~/.config/hypr/bindings.lua.bak.<timestamp>` — backups from every
  keyboard-shortcut change (see above). Safe to delete once you're happy with
  your shortcut.

## Uninstalling

`omarchy plugin remove io.github.aryan-techie.todoist` removes the plugin
files but does **not** touch the two locations above — if you set a keyboard
shortcut, remove it from Settings first (or delete the matching `o.bind`
line from `bindings.lua` yourself), and delete the state directory if you
want your token gone too.

## Todoist API

Uses the [Todoist API v1](https://developer.todoist.com/api/v1/):
`GET /tasks/filter` (or plain `GET /tasks` for the All view), `POST
/tasks/quick` (Quick Add, natural-language parsing) for new tasks, `POST
/tasks/{id}` to edit a task's title, `POST /tasks/{id}/close` to complete,
`DELETE /tasks/{id}` to delete. `Enter` opens
`https://app.todoist.com/app/task/{id}` in your default browser. The older
REST API v2 was retired by Todoist in February 2026, so this plugin only
supports the current API.

## License

MIT — see [LICENSE](LICENSE).
