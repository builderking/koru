# Koru Interaction Model and User Flows

## 1. Interaction model

Koru has two invocation models and one insertion rule.

### Invocation A — initial typed matching

Koru may show saved-item suggestions while the user enters the first uninterrupted characters in a newly focused, empty input. This is the only automatic typed-matching context.

Examples:

- `pus` can surface saved items related to “Push to GitHub.”
- `clp` opens recent mixed clipboard items.

The user's typed text remains in the destination. The panel is a suggestion surface, not an automatic replacement engine.

### Invocation B — manual recall

A configurable global shortcut opens the same recall panel during established writing where macOS permits shortcut registration. It appears near the caret when reliable bounds are available and at the documented stable fallback otherwise. Search happens inside Koru, so no trigger characters are added to the destination.

### The insertion rule

Koru changes destination text only after a distinct user selection:

- Return on a focused result;
- an explicit numbered shortcut;
- a pointer click on a result;
- completion and confirmation of a template.

Focus is not selection. Showing the panel, ranking an item first, or moving highlight with arrow keys never inserts content. This follows Apple's guidance to avoid context-changing selection merely because an item receives focus; see [Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection/).

## 2. Input-session state model

| State | Entry condition | Automatic matching | Exit condition |
| --- | --- | --- | --- |
| Inactive | No eligible editable control has focus | Off | Eligible empty control receives focus |
| Eligible | Empty, nonsecure editable control receives focus with caret at position zero | Ready | Initial characters begin, or any disqualifying event occurs |
| Matching | Initial uninterrupted non-whitespace characters are being entered | On | Selection, dismissal, whitespace, newline, paste, caret move, focus change, or other disqualifying event |
| Committed writing | The initial run has ended or writing already existed | Off | Field becomes empty and receives focus as a new session |
| Suspended | Secure field, IME composition, excluded app, missing permission, or user pause | Off | Suspension condition clears and a new eligible session begins |

Disqualifying events never remove or rewrite the characters already entered.

Clearing a field while it remains focused does not automatically create a new eligible session. This prevents suggestions from reappearing unexpectedly during editing. The empty field must receive focus again, or the user can invoke manual recall.

## 3. Recall-panel behavior

### Placement

- Prefer the active caret or selected-text bounds.
- Keep the panel fully within the active display's visible frame.
- If caret bounds are unavailable, anchor to the active text control.
- If neither is reliable, use a stable compact fallback near the active window rather than guessing a text position.

### Focus

- Initial typed matching keeps typing in the destination field; Koru reflects the destination's initial fragment as the query.
- From an automatic panel, Tab can deliberately transfer focus into Koru's panel search without changing the original destination fragment. This enables deeper Clipboard filtering after `clp` while preserving the exact replacement span.
- Manual recall moves keyboard focus into Koru's search field because the query is not part of the destination.
- Result focus begins on the best match, but no result is preselected for insertion.
- Escape returns to the destination without changing text.

### Sources

- **Saved** is the default source for an ordinary initial fragment and manual recall.
- **Clipboard** opens directly for `clp` and remains available from manual recall.
- **All** may be offered in manual recall, but Saved and Clipboard must remain identifiable in every row.

### Core keys

| Key | Result |
| --- | --- |
| Up / Down | Move result focus |
| Return | Select focused result or continue a template |
| Escape | Cancel current surface; change no destination text |
| Tab / Shift-Tab | Move among search, source, result, and secondary actions |
| Command-1 through Command-9 | Select the visible result with that number, when enabled |
| Command-Return | Use the visible alternate insertion action, such as plain text, when clearly labeled |

Key bindings must be configurable where they may conflict with a destination app. Koru must not override standard macOS shortcuts. Apple recommends respecting established system shortcuts and supporting Full Keyboard Access in [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards).

## 4. Flow A — recall a saved item from an initial fragment

### Preconditions

- Full mode is enabled.
- An eligible empty, nonsecure input receives focus.
- At least one saved item matches the initial fragment strongly enough.

### Main flow

1. The user types `pus` at the beginning of the empty input.
2. The destination displays `pus` exactly as typed.
3. Koru opens a compact result panel beside the caret.
4. Saved matches appear, for example:
   - Push current branch to GitHub
   - Push and open a draft pull request
   - Safe force-push checklist
5. The user moves focus with Up/Down or points to a result.
6. No destination text changes while focus moves.
7. The user presses Return or clicks a result.
8. Koru verifies that the same field, focus session, and exact `pus` query span are still active.
9. Koru replaces only `pus` with the selected saved item's content.
10. The panel closes and focus remains in the destination after the inserted content.

### Alternate flows

- **Keep typing normally:** When the user types a space, newline, or otherwise leaves the initial run, Koru closes and leaves the writing untouched.
- **Dismiss:** Escape closes the panel and leaves `pus` untouched.
- **No confident match:** Koru stays hidden; the user experiences normal typing.
- **Destination changed:** Koru cancels insertion and offers Copy from its panel.
- **Template result:** Continue to Flow E before any destination text changes.

## 5. Flow B — open mixed clipboard results with `clp`

### Preconditions

- Clipboard history is enabled.
- An eligible empty input receives focus.

### Main flow

1. The user types `clp`.
2. `clp` remains visible in the destination.
3. Koru opens Clipboard and lists recent supported entries in one mixed result list.
4. Text rows show a compact text preview; URLs show their address or title; images show a thumbnail; file references show name and type.
5. The user can immediately choose a recent entry, or press Tab to move into the panel search and filter by text, URL, file name, source, or available metadata.
6. Moving search focus into the panel leaves the original `clp` span unchanged in the destination.
7. The user explicitly selects an entry.
8. Koru verifies the destination and replaces only the initial `clp` span when the destination accepts the selected representation.
9. The panel closes.

### Alternate flows

- **Literal `clp`:** Escape or continued normal writing keeps the characters unchanged.
- **Unsupported destination type:** Keep `clp`, retain the result, and offer Copy, Drag, or Reveal rather than attempting an unsafe paste.
- **Missing file:** Mark the result unavailable and keep the destination unchanged.
- **Save permanently:** A result action opens the save flow and creates a separate saved item after confirmation. The original clipboard entry keeps its existing expiry, and saving does not insert unless the user separately chooses Insert.
- **History paused or empty:** Show a compact explanation and a Resume or Settings action; never show a blank ambiguous panel.

## 6. Flow C — manual recall during established writing

### Preconditions

- A nonsecure editable destination has focus.

### Main flow

1. The user invokes the configurable global recall shortcut.
2. Koru reads the destination caret or active selection without changing it.
3. The recall panel appears beside the caret or selection.
4. Focus moves to Koru's search field.
5. The user searches across Saved, Clipboard, or All.
6. The user explicitly selects a result.
7. Koru revalidates the destination.
8. With no destination selection, Koru inserts at the caret.
9. With a destination selection, Koru replaces only that selected range after clearly showing the replacement intent.
10. Koru closes and returns focus to the destination.

### Alternate flows

- **No reliable destination:** Koru supports Copy only.
- **Recall invoked in a secure field:** Koru does not read or insert content and explains the restriction without exposing field contents.
- **Destination app switches:** Koru cancels direct insertion and retains a Copy action.
- **Permission missing:** Koru opens in the supported fallback mode and exposes Repair Permissions.

## 7. Flow D — save all selected text

### Pointer path

1. The user selects all text in a nonsecure editable control.
2. If the optional selection affordance is enabled, Koru can prove that the selected range starts at zero and equals the control's full character count, and selection bounds are reliable, a tiny save icon appears near the selection boundary.
3. The user clicks the icon.
4. A compact save popover opens with the exact selected content prefilled.
5. The user chooses Saved text, Quick replacement, or Template.
6. Koru suggests a local title from the first useful line.
7. The user confirms Save.
8. The source selection and content remain unchanged.
9. Koru gives a brief, nonmodal saved confirmation and closes.

### Keyboard path

1. The user selects the desired text, including Select All when appropriate.
2. The user invokes Save Selection from the configured shortcut or menu.
3. The same save popover opens.
4. The user completes and confirms the save.

### Alternate flows

- **Selection is read-only:** Keyboard/menu capture may copy and save only when macOS exposes the selected text reliably; the floating icon stays hidden.
- **Selection changes before Save:** Refresh only after confirmation or cancel and ask the user to retry; never save an unknown range.
- **Duplicate content:** Offer Open existing, Update existing, or Save separately.
- **Cancel:** Close and preserve selection and source content.
- **Secure/protected text:** Do not show or perform capture.

## 8. Flow E — fill and insert a template

1. The user explicitly chooses a Template result.
2. The destination remains unchanged.
3. A compact field-completion surface replaces or extends the result panel.
4. The first required field receives focus.
5. The user enters values and advances with Return or Tab.
6. A concise preview updates locally.
7. Missing required values are announced and visually identified.
8. The user confirms Insert.
9. Koru validates the destination and renders the final text.
10. Koru replaces only the original query span, active selection, or caret location defined by the invocation flow.
11. Filled values are discarded after insertion unless the user explicitly chooses Update Template.

Cancel at any point leaves the destination unchanged. In an initial typed match, the original fragment remains exactly as typed.

## 9. Flow F — save a clipboard entry permanently

1. The user opens Clipboard through `clp`, manual recall, or the library.
2. The user focuses an entry and chooses Save.
3. Koru opens the save popover with a suitable representation prefilled.
4. The user selects Saved text, Quick replacement, or Template when the content supports it.
5. The user confirms Save.
6. Koru creates a new permanent saved item.
7. The original clipboard entry continues to follow its normal retention policy.

Saving is not called “Pin” because pinning blurs the temporary/permanent boundary. A pinned permanent item belongs in Saved.

## 10. Flow G — onboarding and permission choice

1. Koru explains the product in one sentence and offers a short local demonstration.
2. The user chooses Full mode or Hotkey-only mode.
3. For Full mode, Koru explains why Accessibility and Input Monitoring are needed before opening the relevant macOS permission UI.
4. Clipboard history is enabled through a separate explicit choice with retention and exclusion defaults visible.
5. Koru offers a safe practice field.
6. The user saves a sample, opens recall, selects it, and sees insertion work.
7. Koru offers Launch at Login and finishes onboarding.

The flow must remain usable when any optional permission is denied. The mode summary must accurately reflect active capabilities.

## 11. Flow H — manage the library

1. The user opens Library from the menu bar or recall-panel action.
2. Saved opens by default; Clipboard is a separate destination.
3. Search immediately filters the current source.
4. Selecting a saved item opens its details without entering edit mode automatically.
5. Edit is explicit; Save and Cancel are always available.
6. Archive removes the item from normal recall without deleting it.
7. Delete moves the item to local recovery before final removal.
8. Export is available from a clear library or settings action.

Routine insertion should not require this flow. The library exists for deliberate management, not everyday recall.

## 12. Error and recovery interaction

| Condition | User-facing behavior |
| --- | --- |
| No results | Show “No saved matches” or “No clipboard matches,” preserve query, and offer source switch or Create Saved Item. |
| Permission missing | State the unavailable capability and show Open Settings; keep supported actions available. |
| Insertion failed | Preserve document text, keep the item visible, and offer Copy. |
| Destination moved | Say “The writing location changed” and offer Copy; do not guess. |
| Clipboard item expired | Remove or mark the row unavailable without a blocking alert. |
| File reference missing | Show Missing file with Remove and, when useful, Locate. |
| Storage limit reached | Apply documented retention policy and expose Review Storage; do not block saved-item use. |
| Shortcut conflict | Explain the conflict and open shortcut configuration. |
| App excluded | Keep Koru inactive and make the exclusion visible from the menu-bar status. |

## 13. Interaction acceptance checklist

- [ ] Initial typed matching occurs only in a new eligible empty input session.
- [ ] Mid-writing text never activates automatic typed matching.
- [ ] `pus` can show saved matches without changing `pus`.
- [ ] `clp` opens mixed clipboard results without changing `clp`.
- [ ] Focused results never insert until selected.
- [ ] Escape preserves destination content in every flow.
- [ ] Destination state is revalidated before every insertion.
- [ ] Manual recall works during established writing.
- [ ] Select-all capture exposes keyboard, menu, and Service alternatives, and unavailable host selection support is explained without altering the clipboard or source text.
- [ ] Templates never write partial output before final confirmation.
- [ ] Saved and Clipboard remain distinguishable.
- [ ] Every error retains a safe Copy or retry path when relevant.
- [ ] Core flows are usable with keyboard alone and announced by VoiceOver.

## References

- [Apple Human Interface Guidelines: Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection/)
- [Apple Human Interface Guidelines: Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards)
- [Apple Human Interface Guidelines: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/)
