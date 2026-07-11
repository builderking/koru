# Uninstall Koru

Koru is not implemented yet; final identifiers and paths must be verified against the shipped app before this guide is declared release-ready.

For a clean future uninstall:

1. Export saved items only if wanted; plaintext export is sensitive.
2. Use Koru's explicit **Delete All Data** action. Confirm that it stops integrations and removes the Keychain vault key, active encrypted database, encrypted assets, backups, in-memory index, and selected preferences.
3. Disable Launch at Login and quit Koru.
4. Revoke Accessibility and Input Monitoring in System Settings if macOS retains entries.
5. Move Koru from Applications to Trash.
6. On a test account, verify the finalized Koru Application Support/container, preferences, caches, logs, and Keychain service identifiers no longer contain Koru-managed live data.

Dragging the app to Trash alone does not delete application data. Deletion cannot guarantee forensic removal from APFS/SSD remnants, snapshots, Time Machine, external backups, or previously exported files.

Manual gate: replace this checklist with exact bundle ID, Keychain service, and filesystem paths after TASK-010/TASK-022 define them and `MAN-CLEAN-001` passes.
