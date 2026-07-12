# Koru Product Requirements

## 1. Purpose

This document defines the initial product requirements for Koru, a free, open-source, local-first macOS writing memory.

The product must deliver one dependable loop:

> Save useful writing with exact tags, surface it when a complete tag is typed or through fuzzy manual recall, explicitly choose it, and insert it at the current caret.

Clipboard history supports that loop as temporary memory. It is not the product's primary identity.

## 2. Goals

1. Make automatic recall predictable through exact tags while keeping fuzzy discovery available in manual recall.
2. Keep the user in the current application during recall, selection, and insertion.
3. Make saving freshly written text fast and reversible.
4. Support reusable text and mixed clipboard use cases without prompt-specific vocabulary.
5. Prevent accidental replacement while allowing exact-tag recall anywhere the user writes.
6. Work locally, without an account or network connection.
7. Provide a compact, native, keyboard-first, accessible macOS experience.

## 3. Core vocabulary

| Term | Definition |
| --- | --- |
| Saved item | Permanent reusable text with one or more assigned exact trigger tags. |
| Trigger tag | A user-assigned word or phrase whose complete suffix can open automatic recall. |
| Clipboard entry | A temporary local record of supported pasteboard content. |
| Recall panel | The compact, caret-adjacent surface used to find and select content. |
| Automatic exact-tag matching | Suggestions shown when the complete suffix immediately before the caret exactly matches an assigned tag at a left boundary. |
| Manual recall | Recall panel invocation through a configurable global keyboard shortcut or menu command. |

## 4. Initial scope

### Included

- native macOS menu-bar application and library window;
- local saved-item storage and local search;
- saved text with one or more exact word-or-phrase tags and no required title or behavior choice;
- automatic exact-tag matching at a left boundary anywhere in editable writing;
- `clp` as the reserved exact command for mixed clipboard results anywhere;
- global manual recall that works during established writing where macOS permits shortcut registration;
- caret-adjacent result selection and insertion;
- optional select-all save icon plus keyboard and menu equivalents;
- searchable local clipboard history for text, rich text, URLs, images, and file references when the pasteboard exposes those types;
- local retention controls, observed-frontmost-app exclusions, pause, clear, export, and backup, without claiming macOS proves clipboard-source identity;
- permission onboarding and a hotkey-only operating mode;
- keyboard-only and VoiceOver-compatible operation.

### Deferred

- sync across devices;
- shared libraries or team administration;
- OCR-based image search;
- nested folders and complex taxonomies;
- version history beyond basic undo during editing;
- advanced rich-content editing;
- template fields and executable or variable substitution;
- browser extensions;
- iOS, iPadOS, Windows, or Linux clients;
- importers beyond documented basic interchange formats;
- proactive recommendations outside an explicit eligible input or recall action.

## 5. Functional requirements

### REQ-001 — Local-first operation

Koru must provide capture, saved-item search, clipboard search, and insertion without an account or network connection.

Acceptance criteria:

- Core content remains usable with networking disabled.
- No saved text, clipboard content, query text, trigger tag, or destination text is transmitted by default.
- The product can be installed and used without creating an identity.
- Any optional diagnostics are disabled until the user consents and contain no writing content.

### REQ-002 — Operating modes and permissions

Koru must support:

- **Full mode**, where automatic exact-tag matching is enabled after the required macOS permissions are granted;
- **Hotkey-only mode**, where automatic typed matching is disabled and recall is manually invoked.

Acceptance criteria:

- Onboarding explains each requested permission immediately before macOS requests it.
- Denying or revoking Input Monitoring does not prevent the library and manual recall from functioning where technically possible.
- Koru shows a clear permission-health state and a direct route to the relevant System Settings page.
- Koru never presents itself as active in a mode whose required permission is missing.

Apple describes Input Monitoring as permission for an app to monitor keyboard, mouse, or trackpad input across apps in [Control access to input monitoring on Mac](https://support.apple.com/guide/mac-help/mchl4cedafb6/mac). Koru's onboarding must therefore explain the narrow purpose and local handling of input clearly.

### REQ-003 — Automatic exact-tag eligibility

Automatic matching evaluates the committed text suffix immediately before the caret after ordinary typing. It is eligible when Full mode is active and all of the following are true:

1. the complete suffix exactly equals an assigned trigger tag after case-, diacritic-, and width-insensitive comparison;
2. the tag contains at least three user-perceived characters;
3. the match begins at the start of the field or immediately after a non-letter/non-number left boundary;
4. the same frontmost process and input generation remain active when results are shown and when insertion is requested.

Koru prefers a post-commit Accessibility value and caret range. When a host exposes neither reliably, Koru may use a bounded, in-memory rolling typed suffix for exact matching. Koru does not apply an automatic-recall secure-field or per-app exclusion rule. macOS Secure Input, protected authorization UI, unavailable committed-text semantics, or denied event-posting access can still prevent observation or insertion and must be reported as platform limitations.

Acceptance criteria:

- Existing paragraphs, text before or after the caret, and moving the caret within editable text do not by themselves disable automatic matching.
- A two-character tag or the first two characters of a longer tag never opens the panel; `dav` may open only when `dav` is an assigned complete tag.
- Multiword tags retain their internal spaces and can match as complete phrases.
- Typing another character, changing focus or application, moving the caret, clicking elsewhere, pasting, or starting uncertain IME composition invalidates a stale automatic match before insertion.
- A preference allows automatic typed matching to be disabled globally.

### REQ-004 — Automatic exact-tag matching

When an eligible exact tag is complete, Koru may surface every saved item assigned to that tag. If more than one eligible tag is a suffix, only the longest complete tag participates.

Acceptance criteria:

- The exact typed tag remains visible and unchanged in the destination field while results are shown.
- Koru does not delete, replace, select, rewrite, or move the matched tag before explicit result selection.
- Results appear only for a complete exact assigned tag or the reserved exact command `clp`; prefix, fuzzy, derived-label, content, and learned matches never open the automatic panel.
- Continuing normal writing past the exact tag dismisses or updates the panel and preserves all text.
- Escape dismisses the panel and preserves all text.
- Merely highlighting a result with arrow keys does not change destination text.
- Multiple tags may point to one item, and multiple items may share the same tag and appear as distinct choices.

### REQ-005 — Manual recall

A configurable global shortcut must open manual recall after writing has begun where macOS permits shortcut registration. The panel appears near the active caret when reliable bounds are available and uses the documented stable fallback otherwise.

Acceptance criteria:

- The shortcut uses a public registered-hotkey path and remains available when Input Monitoring is denied and automatic typed matching is disabled.
- Registration conflicts are detected without taking over an existing system or application shortcut, and the user can choose another binding.
- Manual recall does not require or insert a trigger string into the destination.
- Search input is captured inside the Koru panel.
- If destination text is selected, Koru clearly indicates that insertion will replace the selection.
- If no text is selected, insertion occurs at the caret.
- Canceling manual recall returns focus without changing destination content.
- A menu-bar command provides a pointer-accessible equivalent.

### REQ-006 — Result presentation and explicit selection

The recall panel must present a compact ranked list with enough context to distinguish results.

Each result provides, when applicable:

- matched tag or useful first content line;
- source or content-type indicator;
- a short preview;
- pin or recent state;
- clipboard age and source type.

Acceptance criteria:

- Saved and Clipboard sources are visually and accessibly distinguishable.
- The currently focused row has a native, high-contrast focus state.
- Up/Down moves focus, Return selects, Escape cancels, and Tab reaches secondary controls without trapping focus.
- Pointer selection and keyboard selection produce the same outcome.
- No result is selected merely because it is first or focused.

### REQ-007 — Safe insertion

Koru must change destination content only after explicit selection of a result.

Acceptance criteria:

- In automatic typed matching, insertion replaces only the exact matched tag suffix at its current location, including in the middle or at the end of established writing.
- In manual recall, insertion replaces only the active selection, or inserts at the caret when no selection exists.
- Before insertion, Koru confirms that the destination field, focus, caret or selection, and expected query span have not changed.
- If destination state changed, Koru cancels safely and offers Copy instead of writing to an uncertain location.
- Koru first attempts direct Accessibility replacement of the exact range. If direct replacement or AX selection is unavailable but the same process and input generation remain active, it may synthesize one Backspace per matched user-perceived character and then Command-V. If that fallback cannot be validated or event posting is unavailable, Koru preserves the destination and offers Copy.
- Direct Accessibility insertion does not alter the system clipboard. When a compatibility fallback must use the pasteboard, Koru leaves the chosen item as the current clipboard item rather than racing the destination app with an unsafe automatic restoration, and it communicates that outcome succinctly.
- A standard Undo action can reverse the insertion in the destination app when that app supports undo.

### REQ-008 — Clipboard memory and `clp`

Typing the complete reserved tag `clp` at a left boundary anywhere must open mixed Clipboard results. Manual recall must also expose Clipboard as a source.

Acceptance criteria:

- The raw `clp` text remains untouched until a clipboard result is explicitly selected.
- The user can transfer focus into panel search to filter Clipboard results without extending or changing the original `clp` span.
- Results can include supported text, rich text, URLs, images, and file references in one list.
- Text and URLs are searchable by content; files are searchable by name and available metadata; images without searchable metadata remain browsable by thumbnail and recency.
- Each row communicates type, age, and a safe preview.
- Selecting an entry inserts it when the destination supports the type; otherwise Koru offers Copy, Drag, or Reveal as appropriate.
- Saving a clipboard entry creates a permanent saved item and does not silently extend the original entry's retention.
- Expired, deleted, or missing file references fail safely with a clear recovery message.

Apple's `NSPasteboard` supports multiple items and common representations including URLs, colors, images, strings, attributed strings, and sounds; representation availability is controlled by the source application. See [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard).

### REQ-009 — Capture from selected text

When the entire content of a nonsecure editable field is selected, Koru may show a tiny optional save icon near the selection. Koru must also expose configurable-shortcut, menu, and macOS Service entry points; capture succeeds only when Accessibility or the host's Services support exposes the selection reliably.

Acceptance criteria:

- The icon does not appear in secure fields, excluded apps, read-only content, active input-method composition, or when Koru cannot reliably read the selection.
- The icon never changes selection, focus, or document content merely by appearing.
- The icon disappears when the selection changes, focus moves, or the user resumes typing.
- The icon is optional and can be disabled without losing keyboard or menu capture.
- Activating the icon opens a compact save surface with the selected content prefilled.
- VoiceOver and Full Keyboard Access users can perform the same save action without targeting the floating icon.

### REQ-010 — Save content and tags

The save surface contains only the reusable content and its assigned trigger tags.

Acceptance criteria:

- Saved content is never altered during capture.
- A saved item requires nonempty content and at least one nonempty tag.
- The user can assign multiple word-or-phrase tags to the same content.
- No separate title, behavior picker, match-term field, or template editor is required.
- Koru derives any compact display label from the first tag or first useful content line without persisting a second user-authored name.
- Cancel leaves the source text unchanged and creates no saved item.
- Duplicate or near-identical content prompts the user to open, update, or save separately rather than silently duplicating.

### REQ-011 — Trigger-tag validation

Trigger tags must remain predictable and portable.

Acceptance criteria:

- Leading and trailing whitespace is removed; internal whitespace is preserved.
- Duplicate tags on one item are removed with case-, diacritic-, and width-insensitive comparison.
- Tags shorter than three user-perceived characters may be stored for organization or manual search but never trigger automatic recall.
- `clp` remains reserved for Clipboard and cannot be assigned to a saved item.
- Tags contain data only; they execute no scripts, commands, variables, or remote lookups.

### REQ-012 — Saved-item library

Koru must provide a separate library window for deliberate management, while keeping everyday recall in the compact panel.

Acceptance criteria:

- Users can create, search, edit, duplicate, archive, delete, pin, and assign multiple tags to saved items.
- Manual search covers tags and content and may use deterministic fuzzy ranking and local learned choices.
- No folder is required to save or find an item.
- Nested folders are not part of the initial release.
- Archived items do not appear in normal recall but remain recoverable.
- Deletion has a local recovery path before final removal.

### REQ-013 — Clipboard controls and sensitive content

Clipboard history must be visibly temporary, bounded, and controllable.

Acceptance criteria:

- Users can choose retention by age and maximum storage.
- Users can pause and resume capture from the menu bar and settings.
- Koru excludes secure/protected content and known concealed or transient pasteboard representations when available.
- Users can exclude applications and clear one entry, a time range, a content type, or all history.
- Clipboard history never implies that an external file is permanently stored when Koru only holds a reference.
- Large or unsupported representations are skipped with an inspectable local reason, not a blocking alert.

### REQ-014 — Portability and open data

Users must be able to export permanent saved items without proprietary lock-in.

Acceptance criteria:

- Export uses a documented, human-inspectable format for text metadata and a documented assets folder when needed.
- Import validation never overwrites existing items without confirmation.
- Export excludes temporary clipboard history by default.
- A separate explicit action is required to export clipboard data.
- The public repository documents the data format and migration expectations.

### REQ-015 — Accessibility

All core flows must work with the keyboard and macOS assistive technologies.

Acceptance criteria:

- Full Keyboard Access reaches every action.
- VoiceOver announces panel purpose, source, result count, focused item, selected action, and insertion outcome.
- Focus is never moved without an initiating user action.
- UI does not rely on color, animation, hover, or pointer precision alone.
- Reduced Motion, Increase Contrast, Reduce Transparency, and system appearance settings are respected.
- Text remains legible at supported system settings without clipping essential content.

Apple recommends relying on system focus behavior, supporting keyboard-only interaction, and labeling controls for assistive technologies in [Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection/) and [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/).

## 6. Nonfunctional requirements

### Performance

- Recall results should appear with a p95 local response time below 150 ms after the qualifying input or shortcut on supported hardware.
- Search and ranking must remain local and responsive with at least 10,000 saved items and the configured maximum clipboard history.
- Panel animation must never delay keyboard input or insertion.

### Reliability

- A failed insertion must preserve destination text and retain an actionable Copy fallback.
- Koru must detect permission loss and destination invalidation before attempting text changes.
- Core flows must be covered across the supported-app compatibility matrix before stable release.

### Privacy and security

- Content telemetry is prohibited.
- Koru does not deliberately exclude secure or password fields from automatic matching, but macOS Secure Input and protected system surfaces may suppress observation or event posting. Selection capture and clipboard collection retain their separately documented privacy controls.
- Local content must use macOS-appropriate file protection and least-privilege permissions.
- Clipboard retention defaults must be conservative and explained during onboarding.

### Quality

- The app must be signed and notarized for public distribution.
- Core user-facing behavior must be documented in the open-source repository.
- Keyboard commands must be user-configurable and checked for conflicts.

## 7. Edge-case requirements

| Edge case | Required behavior |
| --- | --- |
| User types only the beginning of an assigned tag | No automatic panel; the complete tag is required. |
| User types literal `clp` | Escape or continued normal writing keeps `clp`; no clipboard item is inserted without selection. |
| Input already contains text or caret is mid-document | An exact complete tag at the caret may open; other text is irrelevant. |
| Input method editor is composing text | Use verified committed AX text where possible; do not use an uncertain blind suffix to insert. |
| Secure or protected field | Apply no Koru exclusion; if macOS suppresses events, AX, or posting, leave text untouched and expose the supported fallback. |
| App does not expose caret bounds | Anchor to the active control or pointer-safe screen position; retain all keyboard behavior. |
| App does not support direct insertion | Offer Copy and explain the limitation once, without repeated alerts. |
| Destination changes while panel is open | Cancel write and offer Copy. |
| Clipboard file moved or deleted | Mark unavailable and offer Reveal only when a valid path remains. |
| Very large clipboard object | Skip according to limits and keep other entries functioning. |
| Duplicate saved item | Offer open/update/save-separately; never silently duplicate or overwrite. |
| Permissions revoked after an OS update | Degrade to supported features, show status, and guide repair. |
| Multiple screens or Spaces | Keep the panel within the active screen's visible bounds and attached to the active destination. |
| VoiceOver active | Announce state changes without stealing focus from the user's initiated navigation. |

## 8. Explicit non-goals

- Generating, evaluating, or improving writing with an AI model.
- Sending content directly to ChatGPT, Claude, Gemini, or another service.
- Automatically detecting repeated phrases by recording general typing.
- Replacing text based solely on a trigger match.
- Acting as a general launcher, command runner, or automation framework.
- Becoming a permanent archive for copied videos or large files.
- Shipping a team subscription, marketplace, or shared prompt catalog.
- Requiring a title, behavior category, template type, or folder before an item can be saved.
- Designing the product around a “Prompts” tab or prompt-specific object.

## 9. Release-level acceptance

The initial stable release is acceptable only when:

1. automatic matching appears only for complete exact tags of at least three characters at a left boundary, anywhere in writing;
2. no test path changes destination text without explicit selection;
3. capture, recall, selection, insertion, and clipboard promotion work offline;
4. the supported-app matrix meets the reliability thresholds in the launch plan;
5. Koru adds no automatic secure/app exclusion and documented macOS Secure Input limits fail without unintended modification;
6. keyboard-only and VoiceOver test passes are complete;
7. users can export all permanent saved items;
8. the privacy behavior is documented and matches observed network behavior.

## References

- [Apple Support: Control access to input monitoring on Mac](https://support.apple.com/guide/mac-help/mchl4cedafb6/mac)
- [Apple Developer Documentation: NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)
- [Apple Human Interface Guidelines: Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection/)
- [Apple Human Interface Guidelines: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/)
