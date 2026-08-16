## Summary

<!-- What does this change, and why? -->

## Testing

<!-- How did you verify this? At minimum: -->

- [ ] `omarchy plugin validate .` passes
- [ ] Loaded in a live shell (`omarchy-restart-shell` after clearing `~/.cache/quickshell/qmlcache`) with no new warnings/errors in `qs log -p "$OMARCHY_PATH/shell"`
- [ ] Exercised the change manually against a real Todoist account

## Checklist

- [ ] This doesn't add new external dependencies or system-level modifications beyond what's documented in the README's "External dependencies and system-level modifications" section (or I've updated that section to match)
- [ ] Existing keyboard shortcuts still work as documented
- [ ] I've updated the README if this changes user-facing behavior
