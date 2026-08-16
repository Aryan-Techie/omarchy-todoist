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
- Quick-add box creates a new task straight from the popup — supports
  Todoist's natural-language due dates (e.g. `Buy milk tomorrow at 10`).
- Settings view (gear icon) to paste your API token and customize the
  [Todoist filter](https://www.todoist.com/help/articles/introduction-to-filters-V98wIH)
  that decides which tasks show up (defaults to `today | overdue`).
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

## Usage

- **Open/close**: click the bar icon, or
  `omarchy-shell shell toggle io.github.aryan-techie.todoist`.
- `Escape` closes the panel.
- Click a task's circle to mark it complete.
- Type in the box at the top of the list and press Enter (or click **Add**)
  to create a task.
- The ↻ icon refreshes the list; the ⚙ icon opens Settings, where you can
  change the filter or remove your token.
- Middle-click the bar icon to refresh without opening the panel.

## External dependencies and system-level modifications

This plugin runs `curl`, `mkdir`, and `chmod` via Quickshell's `Process` — all
standard on any Omarchy install, no extra packages required. `curl` is the
only thing that talks to the network; every request goes straight to
`https://api.todoist.com/api/v1/` with your token in an `Authorization:
Bearer` header. Nothing else is contacted, and nothing runs with elevated
privileges.

The plugin does not modify Hyprland config, keybindings, or any other
system file. Adding/removing the bar icon only touches your own
`~/.config/omarchy/shell.json` bar layout, the same as any other bar widget
you add or remove through `omarchy bar`.

## State files

- `~/.local/state/omarchy/io.github.aryan-techie.todoist/settings.json` —
  your Todoist API token and filter string. Created on first save; the file
  is `chmod 600`'d right after writing since it holds a secret. Delete it (or
  use **Remove token** in Settings) to disconnect the plugin from your
  account.

## Todoist API

Uses the [Todoist API v1](https://developer.todoist.com/api/v1/)
(`GET /tasks/filter`, `POST /tasks`, `POST /tasks/{id}/close`). The older
REST API v2 was retired by Todoist in February 2026, so this plugin only
supports the current API.

## License

MIT — see [LICENSE](LICENSE).
