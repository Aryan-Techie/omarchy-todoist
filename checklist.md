# Pre-publish checklist

Tracks what's done and what's left before submitting to
[omarchyplugins.com](https://omarchyplugins.com/). See
[roadmap.md](roadmap.md) for feature direction beyond this gate.

## Marketplace requirements (from the publishing guide)

- [x] Public GitHub repository — `aryan-techie/omarchy-todoist`
- [x] Valid `manifest.json` in the repo root (`omarchy plugin validate` passes)
- [x] README
- [x] License (MIT)
- [x] Safe install — no destructive/unexpected system changes on enable
- [x] Safe removal — documented what `omarchy plugin remove` does and
      doesn't clean up (state file, optional keybind line)
- [ ] Preview image (`preview.png`) — optional but recommended; not yet
      captured

## Functional verification

- [x] `omarchy plugin validate` passes
- [x] Loads with no QML errors on the live shell (`qs log`)
- [x] Enabled, placed on the bar, confirmed via `omarchy plugin list --json`
- [x] Real Todoist token saved and working — user confirmed tasks load
- [x] Token file created at `chmod 600` — verified on disk
- [x] Fixed a real binding-loop bug in the header layout caught by watching
      `qs log` during dev testing (Math.max-of-two-children's-implicitHeight
      + anchoring a child back to the parent's own computed height)
- [ ] Complete a real task end-to-end (click the circle, confirm it
      disappears from the list and completes in Todoist itself)
- [ ] Quick-add a real task end-to-end (confirm it shows up in Todoist)
- [ ] Exercise all three quick-view tabs (Today, Inbox, All) with a real
      account that has tasks in more than one place
- [ ] Set the Ctrl+Super+Y shortcut from Settings and confirm it toggles the
      panel; confirm `bindings.lua.bak.*` backup appears and `hyprctl
      configerrors` stays empty
- [ ] Record a custom shortcut, confirm it applies and the old one no longer
      does anything
- [ ] Remove the shortcut from Settings, confirm the `o.bind` line is gone
      from `bindings.lua`
- [ ] Disable → re-enable the plugin, confirm state (token, filter, quick
      view, shortcut) survives
- [ ] `omarchy-shell shell restart`, confirm everything still works cold
- [ ] Remove the plugin (`omarchy plugin remove`), confirm the bar icon
      disappears cleanly and nothing else breaks
- [ ] Test with an invalid/expired token — confirm the error message in
      Settings is clear ("Todoist rejected the API token…")
- [ ] Test with no network — confirm the error message is clear ("Couldn't
      reach Todoist…")

## Known, accepted issues

- Two benign `Binding loop detected for property "height"` warnings in `qs
  log`, from the `height: visible ? implicitHeight : 0` pattern on the
  loading/empty-state `Text` rows. Confirmed this exact warning class
  already exists in Omarchy's own shipped `bluetooth` panel
  (`PanelSectionHeader`), so it's a known Qt Quick engine quirk in this
  environment, not a functional bug — cosmetic log noise only, does not
  affect behavior. Left as-is rather than restructuring further.

## Before hitting submit

- [ ] Work through the "Functional verification" list above with the live
      account
- [ ] Decide on `preview.png` — either capture one or submit without it
- [ ] Re-read README top to bottom as a first-time installer would
- [ ] Bump `manifest.json` version if anything changes after this point
- [ ] Open the submission issue from the omarchyplugins.com page (repo link,
      category, tags) — not something I can do on your behalf since it's
      your GitHub account submitting it
