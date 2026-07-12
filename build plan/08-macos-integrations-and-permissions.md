# 08. macOS Integrations and Permissions

## 1. Permission philosophy

Koru requests broad macOS permissions only for the feature that needs them and only after explaining the reason in Koru's own UI.

Rules:

- Do not present a wall of system prompts on first launch.
- The Library, editor, import/export, Settings, and Diagnostics work with no special permission.
- Typed matching is enabled only after the person explicitly chooses to enable it.
- Clipboard history is a separate opt-in from typed matching.
- Launch at Login is a separate toggle and remains off until chosen.
- A denied or revoked permission disables only its dependent features.
- Koru never instructs a person to grant Screen Recording, Full Disk Access, Automation, microphone, camera, or administrator access.
- Koru does not use private System Settings URL schemes to imply that permission was granted. It verifies state through public APIs after the person returns.

Apple's macOS privacy model makes Accessibility and Input Monitoring intentionally visible because they can expose or control activity in other apps: [Privacy & Security settings](https://support.apple.com/guide/mac-help/-mchl211c911f/mac).

## 2. Permission and feature matrix

| Capability | No special permission | Accessibility | Input Monitoring | General pasteboard allow | Login-item approval |
|---|---:|---:|---:|---:|---:|
| Browse and edit saved text | Yes | No | No | No | No |
| Import/export library | Yes, through explicit file panels | No | No | No | No |
| Global command palette | Yes, through registered hotkey or menu | Optional for caret anchor; required for direct insertion | No | Required only when pasteboard insertion/copy is used | No |
| Automatic exact-tag matching | No | Optional for committed-text validation and caret/range context | Required on systems that gate key listening separately | No | No |
| Caret-adjacent panel | Window fallback only | Required for caret bounds | No | No | No |
| Plain-text insertion | Copy-only fallback | Required for direct replacement and synthetic paste | No | Required only when pasteboard is used | No |
| Mixed clipboard history | No background history | No | No | Required for continuous programmatic reads where macOS gates them | No |
| Clipboard recall | Previously retained items through registered hotkey/menu | Optional for caret context; required for direct target modification | Required only for typed clp | Required for background capture and mixed paste where macOS gates it | No |
| Optional selection icon | No | Required | No | No | No |
| Global Save Selection hotkey | Invocation only | Required for selection read | No | No | No |
| Save Selection Service | Yes in participating apps | No | No | Uses a service-specific pasteboard | No |
| Start Koru at login | No | No | No | No | Required |

The table describes Koru's chosen architecture, not a statement that macOS always shows identical prompts on every OS release. Registered global commands use a separate public hotkey API and do not request Input Monitoring. The Permission Coordinator must preflight actual runtime behavior, while the hotkey registrar reports registration/conflict state separately from TCC permissions.

## 3. Accessibility integration

### 3.1 Why it is required

Accessibility provides the only public cross-application route Koru can use to:

- Resolve the focused editable element.
- Read the committed value suffix and current caret range when the host exposes them.
- Detect when macOS or a protected control withholds usable text semantics.
- Read and set selected text ranges where the target supports them.
- Obtain caret and selection rectangles.
- Observe selection changes for the optional capture icon.
- Replace selected text directly in supported controls.

Apple describes AXUIElement as the client API assistive applications use to communicate with and control accessible applications: [AXUIElement API](https://developer.apple.com/documentation/applicationservices/axuielement_h).

### 3.2 Request flow

1. Koru shows an explanation:
   - What Koru needs to inspect.
   - That Koru keeps only a bounded rolling suffix in memory and never persists it.
   - That Koru does not add a secure-field or app exclusion to automatic recall, while macOS Secure Input may still block observation or insertion.
   - That the feature can be disabled at any time.
2. On explicit confirmation, call AXIsProcessTrustedWithOptions with the system prompt option.
3. Continue showing a waiting state; the call does not grant access and the prompt is asynchronous.
4. When Koru becomes active again, call AXIsProcessTrusted without prompting.
5. Start AX observers only after trust is confirmed.
6. Stop observers and close any panel immediately if trust is revoked.

Apple documents that AXIsProcessTrustedWithOptions reports trust and may asynchronously prompt but does not change the return value: [AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions).

### 3.3 Failure behavior

Accessibility trust is necessary but does not mean every app exposes text semantics. AX calls may report:

- API disabled.
- Attribute or action unsupported.
- Invalid element after UI replacement.
- Cannot complete while the target is unresponsive.
- Notification unsupported.

Koru maps these results to the per-app capability levels defined in section 07. It must never retry in a tight loop.

## 4. Input Monitoring and typed-event observation

### 4.1 Why it may be separately visible

Koru observes key events while another application is frontmost so it can recognize a complete assigned tag or reserved `clp` at a left boundary anywhere in writing. macOS describes Input Monitoring as permission for an app to monitor the keyboard, mouse, or trackpad while other apps are in use: [Control access to Input Monitoring](https://support.apple.com/en-ca/guide/mac-help/mchl4cedafb6/mac).

The implementation uses:

- CGPreflightListenEventAccess to check listening access.
- CGRequestListenEventAccess only after a person enables typed matching.
- CGPreflightPostEventAccess and CGRequestPostEventAccess only if the insertion fallback needs to post Command-V.
- A Core Graphics event tap only for typed matching, its reset conditions, and automatic-panel navigation while the destination retains focus.

Global shortcut registration is not an event-tap feature and must never be used as a reason to request Input Monitoring.

Apple exposes separate preflight and request functions for listening and posting events: [CGPreflightListenEventAccess](https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess%28%29), [CGRequestPostEventAccess](https://developer.apple.com/documentation/coregraphics/cgrequestposteventaccess%28%29).

### 4.2 Data-minimizing event policy

- Do not install an all-events tap.
- Do not retain key-up events unless a test proves they are required.
- Do not inspect mouse movement.
- Never persist the event stream.
- Keep only a bounded rolling suffix associated with the current frontmost process and input generation.
- Include ordinary spaces so assigned phrase tags can match; reset or invalidate on context changes.
- Never send event-derived content to logs, crash reports, update checks, or network clients.
- While the panel is visible, consume only navigation events Koru owns. All other events pass through.

### 4.3 Event-tap health

- Handle tapDisabledByTimeout and tapDisabledByUserInput.
- Revalidate permission before re-enabling.
- Apply bounded backoff after repeated disable events.
- Surface a local diagnostic if the tap cannot be restored.
- Never spin or continuously prompt.

## 5. General pasteboard integration

### 5.1 Clipboard-history behavior

Use NSPasteboard.general and monitor changeCount while history is enabled.

The monitor:

- Reads only after changeCount changes.
- Preserves multiple items as one clipboard event.
- Materializes approved representations before the current NSPasteboardItem becomes stale.
- Avoids requesting large or unknown representations.
- Writes selected recall items through writeObjects or typed pasteboard APIs.

Apple documents that the pasteboard is shared by running apps, can hold multiple items, and is the sole AppKit interface to pasteboard operations: [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard).

### 5.2 Newer macOS pasteboard privacy

On operating systems that expose NSPasteboard.AccessBehavior:

- Read accessBehavior before starting continuous history.
- default and ask mean programmatic reads may prompt.
- alwaysAllow permits background history.
- alwaysDeny disables background capture; user-originated paste-related access may still be allowed by macOS.
- Koru cannot set the state. The person controls it in System Settings.

Enable the monitor only after the person explicitly turns on Clipboard History. If a programmatic read triggers the system alert, keep Koru's explanation visible behind it. If access is denied, stop the timer and preserve already retained history.

Apple states that the General pasteboard defaults to asking for programmatic access and that the person can choose Ask, Always Allow, or Always Deny: [NSPasteboard.AccessBehavior](https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum), [AppKit pasteboard privacy update](https://developer.apple.com/documentation/Updates/AppKit).

On earlier supported macOS versions, the access-behavior API is unavailable. Koru still treats history as an explicit opt-in and applies the same disclosure and exclusion policy.

### 5.3 Universal Clipboard boundary

The general pasteboard participates in Universal Clipboard, but Apple provides no macOS API for controlling that service. Koru records only content that appears on the local general pasteboard while monitoring is active and permitted. It does not promise to fetch content from another device: [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard).

## 6. Secure Input, protected surfaces, and clipboard-sensitive contexts

### 6.1 Automatic recall and macOS Secure Input

Koru does not reject automatic matching solely because AX reports a secure-text-field subrole, protected content, or a sensitive application bundle identifier. The exact-tag matcher follows the same product rule in every field.

This does not create a bypass. macOS or the host may suppress event delivery, return masked or no AX value/range, reject AX modification, or block synthetic event posting under Secure Input and protected authorization surfaces. When that happens, Koru leaves the destination untouched and offers only the capabilities the OS permits, such as manual browse or Copy. Product copy must not promise that Koru works at the login window, FileVault unlock, authorization dialogs, or every password control.

Apple defines kAXSecureTextFieldSubrole as a field intended for sensitive data whose input is displayed as bullets: [kAXSecureTextFieldSubrole](https://developer.apple.com/documentation/applicationservices/kaxsecuretextfieldsubrole).

### 6.2 Clipboard-sensitive application exclusions

Clipboard history may ship a local, versioned default exclusion list for common categories:

- Password managers.
- Authenticators and security-token utilities.
- Keychain and credential-management interfaces.
- Banking or finance applications where the entire app should be treated as sensitive.
- Terminal applications when secure keyboard entry is active or cannot be determined safely.

The list is based on bundle identifiers, is visible and editable, and updates only with a signed Koru release. A person can add any app to Never Save Clipboard From. It does not disable automatic exact-tag recall.

Browser-domain clipboard exclusions are not promised. Without a browser extension or Automation access, Koru cannot reliably identify the site represented by every browser field, and it must not claim per-website protection.

### 6.3 Clipboard-sensitive content

There is no universal public flag proving that arbitrary clipboard text is a password, token, or secret. Koru therefore:

- Applies frontmost sensitive-app exclusions before capture.
- Honors supported pasteboard metadata without relying on undocumented types as the only defense.
- Offers one-click Pause, Clear History, per-app exclusion, and short retention.
- Does not run content-based secret detection in the cloud.
- Does not promise that every secret copied from a browser extension can be identified.

## 7. Caret and selection positioning

Use:

- kAXSelectedTextRangeAttribute for the caret or selection range.
- kAXBoundsForRangeParameterizedAttribute for screen bounds.
- The focused element frame when range bounds are unavailable.
- The active window or mouse fallback only when the UI labels itself as not caret-anchored.

Apple defines the parameterized bounds attribute as the on-screen bounding rectangle for the specified text range: [kAXBoundsForRangeParameterizedAttribute](https://developer.apple.com/documentation/applicationservices/kaxboundsforrangeparameterizedattribute).

The optional selection icon is enabled only when:

- The target is an editable control.
- The selected range starts at zero and equals the control's full character count.
- Koru can read enough full-value/range information to prove Select All rather than a partial selection.
- Bounds are valid and intersect a visible screen.
- The selection remains stable.
- The target is nonsecure and not excluded.
- The person enabled Selection Capture Icon.

AX selected-text-change notifications are useful but not universally implemented: [kAXSelectedTextChangedNotification](https://developer.apple.com/documentation/applicationservices/kaxselectedtextchangednotification).

## 8. macOS Services fallback

Register a processor-style Service through the NSServices Info.plist declaration.

Suggested command name:

- **Save Selection to Koru**

Behavior:

- Accept string and rich-text send types that Koru explicitly supports.
- Read from the service-specific pasteboard.
- Never replace the selection.
- Open Koru's confirmation/editor for the received content.
- Return a concise error through the service callback if no supported representation exists.

Services are a supported public integration, but the host application decides whether and where the command appears. It may be in the Services menu or contextual Services submenu rather than directly beside the selection.

Apple documents the NSServices declaration and the selection-to-service pasteboard flow: [NSServices](https://developer.apple.com/documentation/bundleresources/information-property-list/nsservices), [Services Overview](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/overview.html).

## 9. Global shortcuts

Provide configurable shortcuts for:

- Open Koru.
- Open clipboard recall.
- Save current selection.
- Pause or resume Koru.

Implement them through a separate `GlobalHotKeyRegistrar` backed by the public `RegisterEventHotKey` and `UnregisterEventHotKey` APIs. The application receives a `kEventHotKeyPressed` command containing an opaque hotkey identifier; it does not monitor unrelated keyboard input. Registration therefore does not require Input Monitoring and remains available when the typed-matching event tap is denied, disabled, timed out, or paused independently.

Requirements:

- Detect conflicts and reject shortcuts reserved by macOS.
- Always include a non-Shift/non-Option modifier in default shortcuts.
- Localize physical-key presentation for the active keyboard layout.
- Keep the target application identity before showing UI.
- Preserve the previous valid binding if a replacement cannot be registered.
- Re-register after configuration change and verify behavior after launch, wake, and app update in the supported-OS matrix.
- Expose registered, disabled, conflict, reserved/unsupported, and failed states without presenting a TCC permission prompt.
- If registration is unavailable, menu-bar commands remain available; do not fall back to the CG event tap.

Open Koru and Open Clipboard can show a screen-safe palette with no special permission. Accessibility is still required for caret-relative placement, reading a selection, and direct target modification. Without Accessibility, the palette remains browse/copy capable. The Save Selection shortcut still fires, but Koru tells the person to use the Services command because it cannot read the selection; it does not silently synthesize Copy and disturb the current clipboard.

Apple documents registered hot keys, `RegisterEventHotKey`, and `kEventHotKeyPressed` in the archived [Carbon Event Manager Reference](https://developer.apple.com/library/archive/documentation/Carbon/Reference/Carbon_Event_Manager_Ref/Reference/reference.html). This public but legacy API must remain under compatibility testing on every supported macOS release.

## 10. Launch at Login

Use SMAppService.mainApp.register and unregister on macOS 13 or later.

- Register only after the person turns on Launch at Login.
- Show actual status: not registered, enabled, requires approval, or denied.
- Do not add launch agents by writing plist files.
- Do not install a privileged helper.
- Keep the status-item app alive through normal app lifecycle, not a daemon.

Apple documents that registering the main app makes it launch on subsequent logins subject to user approval: [SMAppService.register](https://developer.apple.com/documentation/servicemanagement/smappservice/register%28%29).

## 11. Installation and distribution

### Decision: direct, notarized, nonsandboxed distribution

Release flow:

1. Download a signed DMG from the official Koru release location.
2. Drag Koru into Applications.
3. Launch Koru and complete progressive permission onboarding.
4. Optionally enable Launch at Login.

No installer package, root prompt, input-method installation, or background daemon is required.

The core build is nonsandboxed because Apple lists use of Accessibility APIs in assistive apps among activities incompatible with App Sandbox. Mac App Store apps must be sandboxed and self-contained, which makes the store a poor fit for Koru's core promise: [Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

Every published binary must:

- Be signed with a Developer ID Application certificate.
- Enable Hardened Runtime.
- Include a secure timestamp.
- Be notarized and stapled.
- Contain no get-task-allow entitlement.
- Pass Gatekeeper assessment from a clean download.

Apple describes these requirements in [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## 12. Permission-state acceptance criteria

1. Fresh install with no permission can open Library, create saved text, import/export, configure retention, and open Diagnostics.
2. Enabling Typed Matching explains and requests input listening; Accessibility is requested separately for better committed-text validation, caret placement, and direct replacement.
3. Revoking Accessibility while a panel is visible removes AX-dependent placement/replacement, invalidates any AX range, and retains only a validated synthetic or Copy fallback.
4. Revoking input listening stops typed matching and its event tap, shows a nonmodal status in Koru, and does not unregister manual global commands.
5. Denying newer-macOS pasteboard access stops new background capture while preserving retained items.
6. Clipboard history can be disabled and cleared without affecting saved items.
7. Automatic recall has no Koru secure/app exclusion; OS-suppressed secure fields produce no unintended modification, while the optional selection icon and clipboard capture follow their separate privacy rules.
8. Save Selection through Services works without Accessibility in the test host application.
9. Launch at Login status matches SMAppService status after registration, denial, revocation, and app update.
10. No path asks for Screen Recording, Full Disk Access, Automation, root, or a system extension.
11. Moving an unsigned development build or changing its signing identity produces a clear contributor-facing permission diagnostic rather than unexplained failure.
12. Every unavailable integration has a usable fallback: menu-bar palette, copy-only insertion, Services capture, or manual paste.
13. Partial selections never show the optional icon, but remain capturable through the supported hotkey or Services path.
14. With Input Monitoring denied, registered Open Koru and Open Clipboard commands still open a screen-safe palette; without Accessibility, placement and insertion degrade to screen-safe and Copy-only behavior.
15. The registered Save Selection command requires no Input Monitoring, but without Accessibility it reads no selection and directs the person to Services.
16. A reserved or conflicting chord produces a registrar-state error and usable menu command without requesting Input Monitoring or starting an event tap.

## 13. Official Apple references

- [AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)
- [AXUIElement API](https://developer.apple.com/documentation/applicationservices/axuielement_h)
- [Input Monitoring settings](https://support.apple.com/en-ca/guide/mac-help/mchl4cedafb6/mac)
- [Quartz Event Services](https://developer.apple.com/documentation/coregraphics/quartz-event-services)
- [Carbon Event Manager Reference: registered hot keys](https://developer.apple.com/library/archive/documentation/Carbon/Reference/Carbon_Event_Manager_Ref/Reference/reference.html)
- [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)
- [NSPasteboard access behavior](https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum)
- [Secure text field subrole](https://developer.apple.com/documentation/applicationservices/kaxsecuretextfieldsubrole)
- [NSServices](https://developer.apple.com/documentation/bundleresources/information-property-list/nsservices)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [App Sandbox restrictions](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
