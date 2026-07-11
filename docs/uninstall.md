# Uninstall Koru

For a clean uninstall:

1. Export saved items only if wanted; plaintext export is sensitive.
2. Use Koru's explicit **Delete All Data** action. Confirm that it stops integrations and removes the Keychain vault key, active encrypted database, encrypted assets, backups, in-memory index, and selected preferences.
3. Disable Launch at Login and quit Koru.
4. Revoke Accessibility and Input Monitoring in System Settings if macOS retains entries.
5. Move Koru from Applications to Trash.
6. Verify `~/Library/Application Support/Koru` is absent, the `io.builderking.koru.vault` / `master-v1` generic-password item is absent from the data-protection Keychain, and the `dev.builderking.koru` login item is disabled. Remove `~/Library/Preferences/dev.builderking.koru.plist` if it exists.

Dragging the app to Trash alone does not delete application data. Deletion cannot guarantee forensic removal from APFS/SSD remnants, snapshots, Time Machine, external backups, or previously exported files.

Manual gate: execute the clean-account `MAN-CLEAN-001` procedure against the signed candidate and record macOS-version evidence. APFS snapshots, backups, and exported plaintext remain outside the app's deletion boundary.
