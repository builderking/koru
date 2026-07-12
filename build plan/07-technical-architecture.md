# 07. Technical Architecture

## 1. Architecture decision

Koru should be a native, local-first macOS menu-bar application built in Swift.

- Use **AppKit** for the application lifecycle, menu-bar item, global event handling, Accessibility bridge, pasteboard integration, Services provider, and caret-adjacent panel.
- Use **SwiftUI** for the library, editor, onboarding, settings, diagnostics, and the panel's content where it does not compromise AppKit window behavior.
- Use a single signed application process for the first release. A helper, daemon, input method, browser extension, kernel extension, and system extension are not required.
- Run as an agent-style menu-bar app and open ordinary windows only for Library, Settings, Onboarding, and Diagnostics.
- Distribute a universal arm64 and x86_64 binary outside the Mac App Store, signed with Developer ID, hardened, and notarized.
- Keep all saved text and clipboard history on the Mac. No account, server, sync, remote search, or content telemetry is part of the core architecture.

This is intentionally not an InputMethodKit product. InputMethodKit can provide candidate windows and text-input-client communication, but it requires Koru to be installed and selected as an input source. That conflicts with people who use multiple keyboard layouts and would create significantly more installation and compatibility risk. Apple describes InputMethodKit as the framework for building full input methods, not lightweight menu-bar utilities: [InputMethodKit](https://developer.apple.com/documentation/inputmethodkit).

## 2. Locked behavior translated into engineering rules

The following are invariants, not preferences:

1. **Typed matching uses a complete exact tag suffix anywhere.**
   - Compare the committed suffix immediately before the current caret with assigned tags.
   - Require a left boundary and at least three user-perceived characters.
   - Partial, fuzzy, derived-label, content, and learned matches cannot open the automatic panel.
   - Existing writing and a caret in the middle of text are valid; a stale process, caret, or input generation is not.

2. **Koru never inserts automatically.**
   - A typed match may only show a tiny suggestion panel.
   - Insertion requires Return, an explicit keyboard selection command, or a click.
   - Dismissing the panel leaves the typed query untouched.

3. **The panel stays beside the caret where the target exposes a reliable caret range.**
   - When the caret rectangle is unavailable, Koru uses a documented fallback position and never pretends the panel is caret-anchored.

4. **The reserved clipboard command is clp.**
   - clp is eligible under the same exact-suffix and left-boundary rule anywhere.
   - It opens mixed clipboard recall for supported text, images, files, and media references.
   - Selecting an item is still explicit; Koru never pastes the first result automatically.

5. **Selection capture is opportunistic.**
   - The optional tiny capture icon appears only when the entire content of a nonsecure editable control is selected and Accessibility exposes both the full text range and reliable bounds.
   - If Koru cannot prove that the selection starts at zero and covers the control's full character count, it does not show the icon.
   - macOS Services and a global capture hotkey remain first-class supported alternatives for arbitrary selections.

6. **Koru adds no automatic secure/app exclusion.**
   - Automatic matching attempts the same exact-tag behavior in every field and application.
   - macOS Secure Input, protected authorization surfaces, unavailable Accessibility state, or denied event posting may still prevent observation or insertion; those paths preserve text and expose the available fallback.

## 3. Minimum macOS version and visual fallback

### Decision: macOS 13 Ventura or later

macOS 13 is the minimum deployment target.

Reasons:

- ServiceManagement's modern SMAppService API is available from macOS 13 and provides the supported login-item path: [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice).
- The core AppKit, Core Graphics event-tap, Accessibility, NSPasteboard, Keychain, CryptoKit, and SwiftUI capabilities Koru needs are available at this baseline.
- Supporting macOS 13 keeps Koru available to Intel Macs that cannot move to the newest visual platform while still permitting a modern Swift codebase.
- The system-integration layer already requires explicit compatibility adapters, so raising the deployment target would not remove the main engineering risk.

Build and test as a universal application. Source contributors may build for one architecture locally, but tagged release artifacts must contain both arm64 and x86_64 slices.

### Visual behavior

- On macOS 26 and later, use standard AppKit and SwiftUI components first so the system supplies the current Liquid Glass appearance. Apply a custom glass effect only to the compact panel where tests show sufficient contrast and performance.
- On macOS 13 through the last pre-Liquid-Glass release, use a standard translucent popover treatment through NSVisualEffectView or SwiftUI material.
- Layout, hit targets, focus behavior, and information hierarchy remain identical across versions. Only material rendering changes.
- Respect Increase Contrast, Reduce Transparency, Reduce Motion, light/dark appearance, and accent-color settings.
- If glass or translucency reduces readability, fall back to an opaque system background with a border and shadow.

Apple recommends using standard components, limiting custom glass effects, and testing transparency and motion accessibility settings: [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass), [NSVisualEffectView](https://developer.apple.com/documentation/appkit/nsvisualeffectview).

## 4. Runtime components

### 4.1 Application coordinator

Owns:

- NSStatusItem and menu.
- Window routing for Library, Settings, Onboarding, and Diagnostics.
- Feature lifecycle as permissions change.
- Sleep, wake, session-lock, and application-termination handling.
- Optional registration of the main app as a login item through SMAppService.

The app must be fully useful as a library even when system permissions are denied. Each integration starts and stops independently based on current permission state.

### 4.2 Permission coordinator

Provides one observable state model for:

- Accessibility trust.
- Input-listening access.
- General pasteboard access behavior where that API exists.
- Login-item status.
- Registered-global-hotkey status: registered, disabled, conflict, reserved/unsupported chord, or registration failure. This is integration state, not a TCC permission.
- Runtime revocation.

No integration may infer permission from a previous launch. It checks before starting and again after the app becomes active or returns from System Settings.

### 4.3 Event tap service

Uses a Core Graphics event tap to observe only the event types necessary for:

- A bounded rolling typed-suffix state machine.
- Reset conditions such as mouse clicks, focus-changing keys, navigation, and application switching.
- Panel-navigation commands while an automatic tiny panel is visible and the destination retains focus.

The event tap is not the global-shortcut registrar. It is enabled only for typed matching and the automatic panel-navigation path. Disabling or denying Input Monitoring stops those features without unregistering manual global commands.

The event-tap callback:

- Performs no database, pasteboard, Accessibility, image-decoding, or UI work.
- Does not allocate large objects.
- Converts the event into a compact internal message and returns immediately.
- Re-enables the tap if macOS reports timeout or user-input disable events.
- Never writes raw characters to disk or logs.

Apple documents event taps as the API for monitoring and filtering the low-level input stream. The API also reports when a tap is disabled for timeout: [Quartz Event Services](https://developer.apple.com/documentation/coregraphics/quartz-event-services), [CGEventType.tapDisabledByTimeout](https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout).

### 4.4 Global hotkey registrar

Use a dedicated `GlobalHotKeyRegistrar` protocol whose production implementation registers discrete keyboard commands with the public Carbon Event Manager `RegisterEventHotKey` API and unregisters them with `UnregisterEventHotKey`.

Responsibilities:

- Register the configured Open Koru, Open Clipboard, Save Selection, and Pause/Resume chords when the app starts or shortcut settings change.
- Receive only `kEventHotKeyPressed` command deliveries and translate the opaque `EventHotKeyID` into a Koru command. It never receives the surrounding key stream or reconstructs typed text.
- Keep registration, unregistration, conflict, and failure state separate from Accessibility, Input Monitoring, and the Core Graphics event tap.
- Snapshot the frontmost process before opening Koru so later caret placement or insertion can be revalidated when Accessibility is available.
- Reject chords that macOS reserves, that conflict with another registration, or that fail on any supported OS in the shortcut matrix. Preserve the previous valid chord when an edit cannot be registered.
- Keep menu-bar commands available when registration fails or a chord conflicts.

Registered commands require no Input Monitoring request. Their downstream actions remain capability-based:

- Open Koru and Open Clipboard can open a screen-safe palette with no special permission.
- Accessibility improves caret anchoring and is required to read a selection or modify another application's text directly.
- Without Accessibility, recall remains browse/copy capable, Save Selection directs the person to the macOS Service, and an unchanged exact-tag context may use the synthetic Backspace-and-paste tier when event posting is permitted.
- Posting Command-V remains a separate post-event permission decision; it is not granted by hotkey registration.

`RegisterEventHotKey` is a public macOS shortcut-registration path, but it is a legacy Carbon API. The feasibility and release matrices must verify registration, conflict behavior, keyboard layouts, sleep/wake, and delivery on every supported macOS version. If Apple removes or materially changes it, replacing the registrar requires an ADR rather than silently falling back to broad event listening. Apple documents hot-key registration and `kEventHotKeyPressed` in the archived [Carbon Event Manager Reference](https://developer.apple.com/library/archive/documentation/Carbon/Reference/Carbon_Event_Manager_Ref/Reference/reference.html).

### 4.5 Accessibility bridge

Wrap all AXUIElement calls behind a protocol so tests can use deterministic fakes.

Responsibilities:

- Resolve the systemwide focused element and owning process.
- Classify editable text fields, text areas, and unsupported/custom controls.
- Read role, subrole, protected-content state, value availability, selected text, and selected range.
- Determine whether selected-range and selected-text attributes are settable.
- Read caret or selection bounds using the bounds-for-range parameterized attribute.
- Observe focused-element, value, and selection changes where the target supports notifications.
- Apply short messaging timeouts and convert AXError values into typed internal failures.

Accessibility is cooperative. Apple states that clients may return not-implemented, invalid-element, cannot-complete, or API-disabled errors. Koru must treat those as normal compatibility outcomes rather than crashes: [AXUIElement API](https://developer.apple.com/documentation/applicationservices/axuielement_h).

### 4.6 Exact-tag suffix state machine

Maintain a bounded per-frontmost-process suffix and a monotonically increasing input generation.

States:

1. **Inactive** — typed matching is disabled, paused, or no printable event has been observed.
2. **Tracking suffix** — ordinary printable input, including spaces inside phrase tags, updates the bounded in-memory suffix and generation; it never blocks the destination event.
3. **Validating committed text** — after a short delay, prefer the current AX value and collapsed caret. If those are unavailable, exact matching may use the rolling suffix. A newer event cancels stale validation.
4. **Panel visible** — the complete suffix exactly matches an assigned tag of at least three characters at a left boundary, or equals `clp`; the context stores the matched tag, process, generation, and AX range/digest when available.
5. **Completed or dismissed** — explicit selection, further typing, click, focus/app/caret change, paste, navigation outside Koru, or uncertain composition invalidates the previous context.

The event-tap callback only appends a compact message and returns. Accessibility validation, exact-tag lookup, and UI work occur off the callback path. Raw suffix characters remain bounded in memory and are never persisted or logged.

### 4.7 Query and ranking service

Inputs:

- Current exact suffix for automatic recall, or the user-entered query for manual recall.
- Mode: saved text or clipboard recall.
- Optional application scope.

Outputs:

- Stable result IDs.
- Derived display label and preview.
- Content type.
- Match reason.
- Usage metadata required for deterministic ranking.

Automatic lookup is not ranked fuzzy search. It considers assigned tags only, requires a complete exact suffix, keeps the longest overlapping tag, and returns all items sharing it. Manual recall separately ranks exact/prefix/contained tags, content matches, local learned selections, pinning, recency, frequency, and deterministic fuzzy tag/content matches.

clp switches to clipboard mode. It does not search saved items unless a later product decision explicitly creates a combined mode.

Manual recall is a separate invocation mode. It moves focus deliberately into Koru search and may expose Saved, Clipboard, or All while preserving a snapshot of the destination caret or selection. Manual fuzzy search never changes automatic exact-tag eligibility.

All decrypted content search happens in memory. The persistent database must not contain a plaintext full-text index of saved-item or clipboard bodies.

### 4.8 Caret panel controller

Use NSPanel with the nonactivating-panel style and embed SwiftUI content with NSHostingView where useful.

Requirements:

- Never activate Koru merely because an automatic suggestion appears.
- Preserve the target application's frontmost status and selection.
- Clamp the panel to the visible frame of the correct display.
- Convert Accessibility screen coordinates to AppKit coordinates correctly across mixed-scale monitors.
- Prefer below-caret placement; flip above when space is insufficient.
- Expose a compact accessibility hierarchy and keyboard navigation.
- Show at most the amount of information that fits the approved tiny-panel design.
- Do not focus a text field when the automatic panel first appears. Continued typing remains in the target input and invalidates or updates the exact-tag state.
- Tab may deliberately transfer focus to panel search. That transition freezes the original matched-tag range, keeps it unchanged, and routes subsequent search text only to Koru until Escape or explicit selection.
- Manual recall deliberately focuses panel search and stores the original destination caret or selection for later revalidation.
- Capture only panel-navigation events while visible; unrelated input continues to the target.

The current AppKit style mask explicitly supports panels that do not activate their owning app: [NSWindow.StyleMask.nonactivatingPanel](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel).

### 4.9 Insertion coordinator

Insertion is a transaction bound to:

- Invocation mode: automatic exact tag, clp, or manual recall.
- Target process ID.
- Target AX element identity.
- Expected replacement range: the matched tag suffix at its actual UTF-16 location for typed/clp invocation, or the snapshotted caret/selection for manual recall.
- Expected target text and selection where readable.
- Selected result ID and content representation.

Revalidate the target immediately before modifying it. If focus, range, process, or value no longer matches, cancel safely.

Every saved item is plain reusable content. It proceeds to insertion only after explicit selection.

Insertion tiers:

1. **Tier A — direct Accessibility replacement**
   - Verify selected-range and selected-text capabilities.
   - Select exactly the matched tag's UTF-16 range wherever it occurs.
   - Replace that selection with plain text.
   - Use only for targets included in the tested compatibility contract.

2. **Tier B — pasteboard plus explicit paste event**
   - Select the exact matched tag range through Accessibility.
   - Put the chosen text, rich text, URL, image, file URL, or grouped representations on NSPasteboard.
   - Post Command-V only after the target is revalidated.
   - Leave the inserted item as the current clipboard item; automatic restoration is unsafe because target applications may read the pasteboard asynchronously.

3. **Tier C — synthetic Backspace plus paste**
   - Use only after explicit selection, successful event-post preflight, and validation that the frontmost process and input generation are unchanged.
   - Write the chosen content to NSPasteboard, post one marked Backspace key pair per user-perceived character in the matched tag, then post Command-V.
   - Mark all generated events with Koru-specific source metadata so the event tap ignores them.
   - This is a best-effort compatibility tier because macOS does not make the multi-event sequence atomic.

4. **Tier D — copy-only fallback**
   - Put the item on NSPasteboard.
   - Close the panel.
   - Tell the person that Koru copied the item and that they should press Command-V.
   - Never delete the typed tag if Koru cannot validate either the AX or synthetic context.

Character-by-character synthetic typing is not an insertion tier. It is layout-dependent, slow for large saved items, and unreliable with input methods.

### 4.10 Clipboard monitor

NSPasteboard does not publish a general clipboard-change notification. Monitor general-pasteboard changeCount with a low-cost timer while clipboard history is enabled.

When changeCount changes:

- Read access behavior first on operating systems that expose it.
- Read all pasteboard items as one logical clipboard event.
- Materialize permitted small representations immediately because pasteboard items become stale when ownership changes.
- Classify types with Uniform Type Identifiers.
- Deduplicate with a content hash without logging content.
- Encrypt accepted content before persistence.
- Apply sensitive-app exclusions and retention rules before writing.

Supported storage policy:

- Plain text, RTF, HTML, and web URLs: store an encrypted canonical representation plus safe display metadata.
- Images: normalize a bounded preview and encrypt the retained image representation subject to size policy.
- Files: store encrypted metadata and a bookmark or reference. Do not duplicate the file automatically.
- Videos and large media: store a file reference and thumbnail metadata only. Saving the clipboard entry may create a permanent saved-item reference, but V1 does not duplicate a full media asset into Koru automatically.
- Unsupported or provider-specific data: show as unsupported only during the current pasteboard lifetime; do not persist opaque data without a documented format and size policy.

Apple documents changeCount, supported pasteboard types, multiple items, and the fact that NSPasteboardItem becomes stale after ownership changes: [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard), [NSPasteboardItem](https://developer.apple.com/documentation/appkit/nspasteboarditem).

### 4.11 Selection capture coordinator

Three paths share one capture pipeline:

1. **Optional caret icon**
   - Listen for selected-text changes only in nonsecure, nonexcluded apps.
   - Require an editable control whose selected range starts at zero and equals the full character count.
   - Require a valid bounds rectangle. If the full value or range cannot be verified, do not show the icon.
   - Show only after the selection is stable.
   - Hide immediately on focus change, selection collapse, typing, scroll invalidation, secure state, or app exclusion.

2. **Global capture shortcut**
   - Read the current selection through Accessibility after the explicit shortcut.
   - If AX cannot provide the selection, offer the Services route rather than silently changing the general clipboard.

3. **macOS Service**
   - Receive the selection from the requesting application through the service pasteboard.
   - This is the most reliable public fallback in applications that participate in Services.

The capture pipeline opens a lightweight confirmation/editor. Saving remains explicit.

Apple's Services model transfers the current selection through a service-specific pasteboard: [Services Overview](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/overview.html), [NSServices](https://developer.apple.com/documentation/bundleresources/information-property-list/nsservices).

### 4.12 Encrypted repository

Use SQLite for durable metadata and relationships, with CryptoKit encryption at the application layer.

- Generate a random 256-bit vault key on first launch.
- Store the key in the macOS Keychain using the data-protection keychain and without iCloud synchronization.
- Encrypt saved-item bodies, clipboard payloads, previews, file-reference details, source-application metadata, and exclusion details with AES-GCM.
- Use a fresh nonce for every encrypted payload and bind record ID, schema version, and content type as authenticated additional data.
- Keep only the minimum operational fields plaintext: opaque ID, record kind, encrypted-payload version, retention deadline, byte count, and migration state.
- Model the saved-item lifecycle explicitly as Active, Archived, Recently Deleted, and Permanently Deleted. Archive and Recently Deleted remain encrypted and recoverable through their intended surfaces; final purge removes the record and its owned assets.
- Maintain the searchable body index in an in-memory SQLite/FTS store populated after successful decryption.
- Keep Archived and Recently Deleted items out of ordinary recall, and remove the in-memory index and decrypted caches when Koru is paused, the session locks, or the app terminates.
- Use versioned, transactional migrations and create an encrypted pre-migration backup.

Keychain is designed for small secrets such as encryption keys, while CryptoKit supplies authenticated AES-GCM encryption: [Keychain Services](https://developer.apple.com/documentation/security/keychain-services), [AES.GCM](https://developer.apple.com/documentation/cryptokit/aes/gcm).

## 5. Concurrency model

- **Main actor:** AppKit windows, status item, SwiftUI state exposed to views.
- **Main-run-loop hotkey handler:** `GlobalHotKeyRegistrar` registration lifecycle and delivery of opaque command IDs only.
- **Event-tap thread:** event normalization only.
- **AX serial executor:** all Accessibility messaging and observer lifecycle, with bounded timeouts.
- **Clipboard serial executor:** pasteboard polling, decoding, normalization, and deduplication.
- **Repository actor:** SQLite transactions, encryption/decryption, migrations, and retention.
- **Search actor:** in-memory index and deterministic ranking.

No actor may call synchronously back into the event-tap callback. UI state consumes immutable snapshots with stable IDs.

## 6. Compatibility policy and fallbacks

Koru publishes capabilities, not an unsupported universal promise.

Per target application/control, compatibility may be:

- **Full:** exact-tag matching, caret bounds, direct text insertion, mixed paste where supported, and selection capture.
- **Paste:** exact-tag matching and caret bounds work, but insertion uses pasteboard plus Command-V.
- **Synthetic:** exact-tag matching works from the rolling suffix and insertion uses validated Backspace plus Command-V because AX range replacement is unavailable.
- **Copy-only:** panel can appear, but Koru cannot safely modify the target; selection copies the result for manual paste.
- **Palette-only:** typed matching cannot be observed reliably; the global palette and Services remain available.

Store compatibility decisions locally by bundle identifier and control capability, not by window title or document content. Built-in compatibility overrides ship with releases; there is no remote rules service.

## 7. Hard platform limits

The build and product copy must state these limits:

- Public APIs cannot guarantee a readable value, selected range, or caret rectangle for every custom, canvas-based, terminal, remote-desktop, browser, Electron, or game control.
- Accessibility notifications are optional. The selection icon cannot appear everywhere.
- Koru cannot inject a first-class custom item directly into every application's contextual menu. Services is the supported public mechanism.
- Koru does not run at the login window, FileVault unlock, or protected authorization surfaces.
- A registered chord can be unavailable because macOS or another application already owns it, and modifier/key behavior can vary by OS release and keyboard layout. Koru reports the conflict and preserves menu commands; it does not add broad event listening as a workaround.
- Koru does not deliberately block secure/password fields for automatic recall, but macOS Secure Input and protected authorization surfaces may suppress event delivery, readable text, AX modification, or synthetic posting. Koru cannot override that OS behavior.
- Raw key events do not perfectly represent committed text from all keyboard layouts, dead keys, dictation, or third-party input methods. Unknown composition makes the session ineligible.
- A target application decides whether it accepts images, files, video references, rich text, or only plain text.
- Clipboard history begins only while Koru is running, enabled, and allowed to read the general pasteboard.
- Universal Clipboard participates through the general pasteboard, but Apple provides no direct macOS API for controlling or fetching Universal Clipboard: [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard).
- File and video references can expire, move, or become unavailable. V1 does not archive the full binary automatically, even when the reference is saved as a permanent item.

## 8. Architecture acceptance criteria

1. Typed matching shows a panel only for a complete assigned tag of at least three characters at a left boundary or reserved `clp`.
2. Automated tests prove the same exact-tag behavior at field start, after existing prose, and in the middle of text, while partial, fuzzy, derived-label, content, and stale-generation matches remain hidden.
3. No result inserts without an explicit Return, keyboard selection command, or click.
4. Dismissal leaves the target's typed tag and focus unchanged.
5. The standard AppKit test harness anchors the panel within eight points of the reported caret rectangle on one- and two-display setups.
6. A target mismatch immediately before insertion cancels without deleting or replacing text.
7. Every insertion failure reaches copy-only fallback without content loss.
8. clp returns mixed retained clipboard entries with accurate type labels and never loads a full video asset merely to render a result.
9. Koru adds no secure/app exclusion to automatic recall; OS-suppressed secure contexts fail without unintended modification, while clipboard capture and the optional selection icon retain their separate privacy gates.
10. The optional selection icon never appears for a partial selection; Services and the global capture hotkey remain available.
11. Killing Koru during an encrypted repository write leaves either the previous committed state or the complete new state, never a partially decrypted or corrupt record.
12. Raw keystrokes, selected text, saved-item bodies, clipboard bodies, file paths, window titles, and URLs do not appear in persisted logs.
13. On macOS 13 through the current release, denied or revoked permissions degrade the relevant feature without crashing or blocking Library access.
14. Manual recall during established writing modifies only the snapshotted caret/selection after successful immediate revalidation.
15. Moving a saved item to Recently Deleted removes it from recall without destroying recoverability; Restore returns it to the correct saved-item state, while explicit permanent deletion or recovery-window expiry removes its record and owned assets transactionally.
16. With Input Monitoring denied and the event tap stopped, a successfully registered Open Koru or Open Clipboard command still opens the palette; without Accessibility it uses screen-safe placement and Copy-only behavior.
17. A registered Save Selection command can be invoked without Input Monitoring, but reads no text without Accessibility and instead offers the Services path.
18. Hotkey registration conflict or failure is visible, preserves the last valid configuration where possible, and leaves menu-bar commands usable without installing an event tap.

## 9. Official Apple references

- [AXUIElement API](https://developer.apple.com/documentation/applicationservices/axuielement_h)
- [Bounds for a text range](https://developer.apple.com/documentation/applicationservices/kaxboundsforrangeparameterizedattribute)
- [Global event monitoring](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents%28matching%3Ahandler%3A%29)
- [Carbon Event Manager Reference: registered hot keys](https://developer.apple.com/library/archive/documentation/Carbon/Reference/Carbon_Event_Manager_Ref/Reference/reference.html)
- [Quartz Event Services](https://developer.apple.com/documentation/coregraphics/quartz-event-services)
- [Nonactivating panel](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel)
- [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)
- [NSServices](https://developer.apple.com/documentation/bundleresources/information-property-list/nsservices)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain-services)
- [CryptoKit AES-GCM](https://developer.apple.com/documentation/cryptokit/aes/gcm)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
