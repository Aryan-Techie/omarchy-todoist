# Security Policy

## Scope

This plugin stores your Todoist personal API token locally and sends it to `https://api.todoist.com/api/v1/` over HTTPS. It's worth reading the README's [External dependencies and system-level modifications](README.md#external-dependencies-and-system-level-modifications) and [State files](README.md#state-files) sections for the full picture of what this plugin touches and where your token lives — that's the baseline this policy assumes.

In short:

- Your API token is stored at `~/.local/state/omarchy/io.github.aryan-techie.todoist/settings.json`, `chmod 600`'d immediately after every write.
- The token is only ever sent to `api.todoist.com`, in an `Authorization: Bearer` header, over HTTPS.
- The only system file this plugin can modify outside its own state directory is `~/.config/hypr/bindings.lua`, and only when you explicitly set a keyboard shortcut from Settings (backed up first, rolled back automatically on a bad reload — see the README for details).
- Nothing runs with elevated privileges.

## Reporting a vulnerability

If you find a security issue — a way the token could leak, an injection point in how a shell command gets built, an unexpected file being written or modified outside what's documented above — please report it privately rather than opening a public issue:

**rdngaming25@gmail.com**

Include what you found, the plugin version (`manifest.json`'s `version` field), and reproduction steps if you have them. I'll aim to acknowledge within a few days.

Please don't open a public issue for anything that could let someone else exploit it before a fix ships.

## Out of scope

- Vulnerabilities in Todoist's own API or web app — report those to [Todoist](https://www.todoist.com/help) directly.
- Vulnerabilities in the Omarchy shell itself, outside this plugin's own code — report those to the [Omarchy project](https://github.com/basecamp/omarchy).
