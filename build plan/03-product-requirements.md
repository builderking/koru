# Koru Product Requirements

## 1. Purpose

This document defines the initial product requirements for Koru, a free, open-source, local-first macOS writing memory.

The product must deliver one dependable loop:

> Save useful writing, recall it from an imperfect initial fragment or a manual shortcut, explicitly choose it, and insert it at the current caret.

Clipboard history supports that loop as temporary memory. It is not the product's primary identity.

## 2. Goals

1. Make useful saved writing discoverable without requiring an exact abbreviation.
2. Keep the user in the current application during recall, selection, and insertion.
3. Make saving freshly written text fast and reversible.
4. Support text, template, and mixed clipboard use cases without prompt-specific vocabulary.
5. Prevent accidental replacement and mid-writing interruption.
6. Work locally, without an account or network connection.
7. Provide a compact, native, keyboard-first, accessible macOS experience.

## 3. Core vocabulary

| Term | Definition |
| --- | --- |
| Saved item | A permanent item intentionally kept by the user. |
| Saved text | A saved item inserted as reusable content. |
| Quick replacement | A saved item with preferred initial match terms. It still requires explicit selection before replacement. |
| Template | A saved item with fields the user completes before insertion. |
| Clipboard entry | A temporary local record of supported pasteboard content. |
| Recall panel | The compact, caret-adjacent surface used to find and select content. |
| Initial typed matching | Suggestions based on the first characters in an eligible fresh, empty input session. |
| Manual recall | Recall panel invocation through a configurable global keyboard shortcut or menu command. |

## 4. Initial scope

### Included

- native macOS menu-bar application and library window;
- local saved-item storage and local search;
- saved text, quick replacement, and template behaviors;
- automatic initial typed matching in eligible empty fields only;
- `clp` as the initial typed command for mixed clipboard results;
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
- browser extensions;
- iOS, iPadOS, Windows, or Linux clients;
- importers beyond documented basic interchange formats;
- proactive recommendations outside an explicit eligible input or recall action.

## 5. Functional requirements

### REQ-001 — Local-first operation

Koru must provide capture, saved-item search, clipboard search, template completion, and insertion without an account or network connection.

Acceptance criteria:

- Core content remains usable with networking disabled.
- No saved text, clipboard content, query text, template value, or destination text is transmitted by default.
- The product can be installed and used without creating an identity.
- Any optional diagnostics are disabled until the user consents and contain no writing content.

### REQ-002 — Operating modes and permissions

Koru must support:

- **Full mode**, where initial typed matching is enabled after the required macOS permissions are granted;
- **Hotkey-only mode**, where automatic typed matching is disabled and recall is manually invoked.

Acceptance criteria:

- Onboarding explains each requested permission immediately before macOS requests it.
- Denying or revoking Input Monitoring does not prevent the library and manual recall from functioning where technically possible.
- Koru shows a clear permission-health state and a direct route to the relevant System Settings page.
- Koru never presents itself as active in a mode whose required permission is missing.

Apple describes Input Monitoring as permission for an app to monitor keyboard, mouse, or trackpad input across apps in [Control access to input monitoring on Mac](https://support.apple.com/guide/mac-help/mchl4cedafb6/mac). Koru's onboarding must therefore explain the narrow purpose and local handling of input clearly.

### REQ-003 — Eligible initial input session

Automatic typed matching may run only when all of the following are true:

1. an editable text control has just received focus;
2. its actual value is empty;
3. the caret is at the beginning;
4. there is no selected or marked text;
5. the field is not secure or protected;
6. an input-method composition is not active;
7. the current application is not excluded;
8. Full mode is active.

The eligible window covers only the initial uninterrupted run of non-whitespace characters. It ends when the user types whitespace or a newline, pastes content, moves the caret, creates a selection, dismisses the panel, switches focus, or changes the field through another action.

Acceptance criteria:

- Automatic matching never opens after the user has begun established writing in that field.
- Clearing a nonempty field does not silently restart matching during the same focus session; a new eligible session begins after the field is empty and receives focus again.
- Secure fields and active input-method compositions never trigger matching.
- A preference allows initial typed matching to be disabled globally and per application.

### REQ-004 — Initial typed matching

During an eligible session, Koru may surface saved-item matches after a meaningful initial fragment. A fragment such as `pus` may surface “Push to GitHub” and related items.

Acceptance criteria:

- The typed fragment remains visible and unchanged in the destination field while results are shown.
- Koru does not delete, replace, select, rewrite, or move the fragment before explicit result selection.
- Results appear only when there is a qualifying local match or a recognized command such as `clp`.
- Continuing normal writing past the eligibility boundary dismisses the panel and preserves all text.
- Escape dismisses the panel and preserves all text.
- Merely highlighting a result with arrow keys does not change destination text.
- Initial matching can use titles, explicit match terms, tags, and locally learned query-to-item choices; an exact alias is not required.

### REQ-005 — Manual recall

A configurable global shortcut must open manual recall after writing has begun where macOS permits shortcut registration. The panel appears near the active caret when reliable bounds are available and uses the documented stable fallback otherwise.

Acceptance criteria:

- The shortcut uses a public registered-hotkey path and remains available when Input Monitoring is denied and initial typed matching is disabled.
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

- title or useful first line;
- behavior or content-type indicator;
- a short preview;
- pin or recent state;
- template-field count;
- clipboard age and source type.

Acceptance criteria:

- Saved and Clipboard sources are visually and accessibly distinguishable.
- The currently focused row has a native, high-contrast focus state.
- Up/Down moves focus, Return selects, Escape cancels, and Tab reaches secondary controls without trapping focus.
- Pointer selection and keyboard selection produce the same outcome.
- No result is selected merely because it is first or focused.

### REQ-007 — Safe insertion

Koru must change destination content only after explicit selection of a result or completed template.

Acceptance criteria:

- In initial typed matching, insertion replaces only the exact initial fragment that produced the active results.
- In manual recall, insertion replaces only the active selection, or inserts at the caret when no selection exists.
- Before insertion, Koru confirms that the destination field, focus, caret or selection, and expected query span have not changed.
- If destination state changed, Koru cancels safely and offers Copy instead of writing to an uncertain location.
- Plain-text insertion is available when the target can be modified safely; otherwise Koru preserves the destination and offers Copy. Preserved-format insertion appears only when supported.
- Direct Accessibility insertion does not alter the system clipboard. When a compatibility fallback must use the pasteboard, Koru leaves the chosen item as the current clipboard item rather than racing the destination app with an unsafe automatic restoration, and it communicates that outcome succinctly.
- A standard Undo action can reverse the insertion in the destination app when that app supports undo.

### REQ-008 — Clipboard memory and `clp`

Typing `clp` during an eligible initial session must open mixed Clipboard results. Manual recall must also expose Clipboard as a source.

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

### REQ-010 — Save choices

The save surface must offer neutral behavior choices: Saved text, Quick replacement, and Template.

Acceptance criteria:

- Saved content is never altered during capture.
- Koru suggests a title locally from the first useful line but lets the user change it.
- Saved text can be committed with a title and content only.
- Quick replacement requires at least one preferred initial match term and explains that replacement still requires selection.
- Template creation can convert marked tokens into editable fields before saving.
- Cancel leaves the source text unchanged and creates no saved item.
- Duplicate or near-identical content prompts the user to open, update, or save separately rather than silently duplicating.

### REQ-011 — Templates

A Template must allow a user to complete named values before insertion.

Acceptance criteria:

- Template fields have a label, order, required state, and optional default.
- Choosing a template opens a compact completion surface near the recall panel.
- Return advances or completes according to the current field; Escape cancels without changing destination text.
- Required incomplete fields prevent insertion and show a concise accessible error.
- The rendered preview updates before insertion.
- Filled values are not saved to history by default unless the user explicitly updates the template.

### REQ-012 — Saved-item library

Koru must provide a separate library window for deliberate management, while keeping everyday recall in the compact panel.

Acceptance criteria:

- Users can create, search, edit, duplicate, archive, delete, pin, tag, and change the behavior of saved items.
- Search covers title, content, match terms, and tags.
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
- VoiceOver announces panel purpose, source, result count, focused item, selected action, template errors, and insertion outcome.
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
- Secure fields are out of scope for capture, matching, recall insertion, and clipboard collection.
- Local content must use macOS-appropriate file protection and least-privilege permissions.
- Clipboard retention defaults must be conservative and explained during onboarding.

### Quality

- The app must be signed and notarized for public distribution.
- Core user-facing behavior must be documented in the open-source repository.
- Keyboard commands must be user-configurable and checked for conflicts.

## 7. Edge-case requirements

| Edge case | Required behavior |
| --- | --- |
| User types a normal word beginning with a saved item's fragment | Suggestions may appear only during eligibility; text remains untouched, and whitespace dismisses the panel. |
| User types literal `clp` | Escape or continued normal writing keeps `clp`; no clipboard item is inserted without selection. |
| Input already contains text when focused | No automatic matching. Manual recall remains available. |
| User returns the caret to the start mid-document | No automatic matching. |
| Field is cleared while still focused | No automatic restart until a new eligible focus session. |
| Input method editor is composing text | Suspend matching and floating capture UI. |
| Secure or protected field | Do not observe, capture, suggest, or insert. |
| App does not expose caret bounds | Anchor to the active control or pointer-safe screen position; retain all keyboard behavior. |
| App does not support direct insertion | Offer Copy and explain the limitation once, without repeated alerts. |
| Destination changes while panel is open | Cancel write and offer Copy. |
| Clipboard file moved or deleted | Mark unavailable and offer Reveal only when a valid path remains. |
| Very large clipboard object | Skip according to limits and keep other entries functioning. |
| Duplicate saved item | Offer open/update/save-separately; never silently duplicate or overwrite. |
| Template is canceled | Destination text and initial query remain unchanged. |
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
- Requiring tags, aliases, or folders before an item can be useful.
- Designing the product around a “Prompts” tab or prompt-specific object.

## 9. Release-level acceptance

The initial stable release is acceptable only when:

1. automatic matching is demonstrably confined to eligible initial sessions;
2. no test path changes destination text without explicit selection;
3. capture, recall, selection, insertion, and clipboard promotion work offline;
4. the supported-app matrix meets the reliability thresholds in the launch plan;
5. secure contexts are excluded;
6. keyboard-only and VoiceOver test passes are complete;
7. users can export all permanent saved items;
8. the privacy behavior is documented and matches observed network behavior.

## References

- [Apple Support: Control access to input monitoring on Mac](https://support.apple.com/guide/mac-help/mchl4cedafb6/mac)
- [Apple Developer Documentation: NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)
- [Apple Human Interface Guidelines: Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection/)
- [Apple Human Interface Guidelines: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/)
