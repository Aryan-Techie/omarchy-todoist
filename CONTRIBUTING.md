# Contributing

Thanks for considering a contribution to this plugin. It's a small project — this doc is short on purpose.

## Before you start

For anything beyond a small fix, open an issue first (or comment on an existing one) so we can agree on the approach before you put time into it. That's especially true for new keyboard shortcuts, new Settings fields, or anything that talks to a new Todoist API endpoint.

## Project layout

- `BarWidget.qml` — the bar pill. Thin: reads state back from `Panel.qml`, decides what the pill shows.
- `Panel.qml` — everything else. State, Todoist API calls (via `curl` `Process`es), settings persistence, and the panel UI, all in one file.
- `Model.js` — pure data helpers only (sorting, date math, error-message formatting). No QML/Qt types here, so it stays easy to reason about in isolation.
- `set-keybind.sh` — the one thing that touches a system file outside the plugin's own state directory (`~/.config/hypr/bindings.lua`), and only when you explicitly set a shortcut from Settings.

## Conventions worth knowing before you dig in

- **`Panel.qml` stays a single file.** This matches how Omarchy's own built-in panels (bluetooth, audio — both bigger than this file) are structured: one file per widget, with QML's inline `component Name: Base { ... }` syntax for internal pieces like `TaskRow`. Don't split it into multiple component files.
- **HTTP goes through `Quickshell.Io Process` running `curl -fsS`, never QML XHR.** This matches every built-in panel in the shell.
- **Settings persist to `~/.local/state/omarchy/<plugin-id>/settings.json`**, `chmod 600`'d after every write since it holds your API token. Don't add anything else that writes files outside this and the one keybind case above without calling it out clearly in the README.
- **Keyboard handling is real work here**, not an afterthought — the panel is meant to be fully usable without a mouse. If you add a control, it needs to be reachable by keyboard too (see the existing `NavButton`/`NavActionButton` wrapper components and `settingsFocusChain()` for the pattern Settings uses). If you're integrating a shared `Ui/` component that doesn't expose its internal focusable element for an external `forceActiveFocus()` (`Dropdown`, `MultiSelect` are like this), test the actual keyboard flow yourself before calling it done — a clean `qs log` and `omarchy plugin validate` don't prove the keyboard interaction works.

## Making a change

1. Edit the files in your checkout.
2. `omarchy plugin validate .` — this is the reliable structural check; `qmllint` doesn't work against this shell's runtime-only `qs.*` namespaces, so don't rely on it.
3. Install (or symlink-free copy — `omarchy plugin validate` rejects symlinked plugin folders) your checkout to `~/.config/omarchy/plugins/io.github.aryan-techie.todoist/` for live testing.
4. Clear the QML cache and restart the shell to pick up changes cleanly: `rm -rf ~/.cache/quickshell/qmlcache && omarchy-restart-shell`.
5. Check `qs log -p "$OMARCHY_PATH/shell"` for new warnings or errors.
6. Test the actual behavior against a real Todoist account — a clean log doesn't mean the feature works, only that it loaded.

## Submitting a PR

- Keep PRs focused — one change, one PR, easier to review.
- Update the README if you change anything user-facing (a shortcut, a setting, the refresh behavior, what data leaves the machine).
- Fill in the PR template's testing checklist honestly — "I read the code" isn't the same as "I ran it."

## Reporting bugs / requesting features

Use the issue templates — they ask for the specific things that make a report actionable (plugin version, repro steps, `qs log` output).

## Security

Found a security issue (something to do with how the API token is stored/transmitted, or an unexpected system-level modification)? See [SECURITY.md](SECURITY.md) rather than opening a public issue.
