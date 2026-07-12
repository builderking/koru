# Koru UX Design System and Accessibility

## 1. Design direction

Koru should look and behave like a focused, current native macOS utility:

- minimal and calm;
- light and visually open by default;
- compact without becoming cramped;
- small, legible system typography;
- low copy and high information clarity;
- keyboard-first with complete pointer and assistive-technology support;
- visually subordinate to the application where the user is writing.

This document intentionally stays at system and behavior level. It does not lock a mockup, brand palette, exact panel dimensions, decorative treatment, or custom component language. Those decisions should follow an approved visual direction and native implementation tests.

## 2. Experience qualities

### Quiet

Koru appears for a specific task and leaves immediately after completion. It does not use celebratory animation, persistent coaching, large empty states, or attention-seeking status.

### Native

Use AppKit or native macOS component behavior, system typography, semantic colors, standard menu placement, platform focus treatment, and system appearance settings wherever they satisfy the need.

Apple's [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/) guidance emphasizes keyboard shortcuts, flexible window behavior, menu-bar access, and familiar system interactions. Koru should build from those patterns rather than imitate a web command palette.

### Compact

The recall panel shows only enough content to identify and select a result. Deeper metadata and management belong in the library.

### Explicit

Focus, selection, save, insertion, and deletion have visibly distinct states. No visual emphasis implies that an item has already been inserted or saved.

### Reassuring

Privacy, permission, and fallback states use direct language. Koru never hides a degraded capability behind optimistic status copy.

## 3. Visual system

### 3.1 Typography

- Use the macOS system font and semantic system text styles.
- Use standard body/control sizing for primary content and system small/caption sizing for metadata.
- Keep hierarchy shallow: content-derived label or preview, tag/source metadata.
- Avoid all-caps labels and excessive weight contrast.
- Permit truncation in list previews, but never in the full preview, editor, permission explanation, or error recovery action.
- Respect accessibility text and display settings; compactness must yield before legibility.

Apple's current [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/) guidance lists 13 pt as a default macOS text size and 10 pt as a minimum. Koru should treat the minimum as an exception for secondary metadata, not a target for core content.

### 3.2 Color and appearance

- Use semantic system colors so light, dark, increased-contrast, and inactive-window states remain correct.
- The primary art direction is light and clean, but the product must follow the user's system appearance.
- Use one restrained accent for selection and primary actions.
- Do not encode Saved versus Clipboard, availability, or error state through color alone.
- Avoid large saturated surfaces, decorative gradients, and custom translucency that competes with destination content.
- Respect Reduce Transparency with an opaque system-equivalent background.

### 3.3 Materials, borders, and elevation

- Prefer current native panel, popover, menu, and window materials.
- Use separation only where it clarifies source, focus, or hierarchy.
- Keep border radius, shadow, and elevation aligned with current macOS components rather than creating a branded card system.
- The caret-adjacent surface must remain visually distinct from the destination without resembling a blocking modal.

### 3.4 Icons

- Prefer SF Symbols or native system icons.
- Pair unfamiliar icons with an accessible label or tooltip.
- The optional save affordance may be icon-only visually, but it requires a clear accessibility label such as “Save selected text to Koru.”
- Do not use emoji as control icons.
- Do not create different decorative icons or item types for prompt, snippet, replacement, and other reusable text.

### 3.5 Density and spacing

- The recall panel uses compact rows and a short visible result set, with scrolling for more.
- Row spacing must preserve scanability and a reliable pointer target.
- Primary controls use normal macOS control dimensions; secondary icon controls must still meet accessible target requirements.
- The library may use denser information presentation than the save flow, but edit controls must remain easy to distinguish.

Apple's accessibility guidance recommends a default macOS control size of 28 × 28 pt and a minimum of 20 × 20 pt, with adequate spacing around controls. See [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/).

## 4. Core component guidance

### 4.1 Recall panel

Purpose: find, distinguish, and explicitly select a result.

Required elements:

- source indicator;
- the exact matched tag for automatic recall or the entered query for manual recall;
- result count communicated accessibly;
- result list;
- visible focused-row treatment;
- concise empty, paused, or permission state;
- safe alternate action such as Copy when direct insertion is unavailable.

The panel should not normally show:

- a sidebar;
- rich item editing;
- settings forms;
- onboarding content;
- decorative headers;
- persistent usage analytics;
- multi-paragraph descriptions.

### 4.2 Result row

Each row may include:

- a content-derived saved-text label or derived clipboard label;
- a one- or two-line preview;
- source/type or exact-tag metadata;
- thumbnail for images where useful;
- age for clipboard entries;
- small unavailable-state indicator.

The entire row is the primary selection target. Secondary actions must not crowd the scanning path and should appear through a standard action menu or accessible details route.

Focused, hovered, pressed, unavailable, and selected-for-action states must be visibly distinct. Focus alone must never imply insertion.

### 4.3 Save icon

- Appears only for a reliable select-all state in a supported nonsecure field.
- Remains visually small but uses an accessible hit target.
- Does not cover selected text, native handles, validation messages, or nearby app controls.
- Disappears on selection change, typing, scrolling that invalidates its anchor, or focus loss.
- Has no timed auto-dismiss while it holds keyboard or assistive-technology focus.
- Can be disabled globally.

### 4.4 Save popover

The initial state contains:

- exact content preview;
- one or more exact trigger-tag fields, each at least three characters;
- Save and Cancel.

Content and at least one valid tag are the only required inputs. Copy should remain concise and use the term saved item.

### 4.5 Tag editing

- Accept one or more exact word-or-phrase tags.
- Explain the three-character minimum and reserved `clp` conflict inline.
- Preserve entered content and valid tags while correcting validation errors.
- Cancel changes no destination content and persists no draft.

### 4.6 Library window

- Use a familiar macOS window hierarchy and toolbar/search placement.
- Saved, Clipboard, Archive, and Recently Deleted are distinct destinations.
- Selection opens details; Edit is explicit.
- Destructive actions use standard confirmation and recovery patterns.
- Avoid a visually heavy “productivity dashboard” treatment.

### 4.7 Menu-bar status

The status menu communicates:

- active mode;
- Clipboard active/paused;
- permission issue when one exists;
- direct commands.

Status must be available as text within the menu; icon changes alone are insufficient.

## 5. Focus and keyboard system

Koru relies on a precise distinction between the destination's focus and Koru's focus.

### Automatic exact-tag matching

- Destination text control retains typing focus.
- The panel may appear at the beginning, middle, or end of ordinary writing only after a complete assigned tag of at least three characters at a left boundary.
- Partial, fuzzy, content, and derived-label matches remain manual-search-only.
- Koru displays result focus as a navigable suggestion state.
- Arrow navigation is used only when it can be captured without corrupting destination editing.
- Return inserts only after the user has deliberately moved or confirmed result focus according to the tested interaction contract.
- Escape dismisses without changing destination text.

### Manual recall

- Focus moves into Koru's search field after the user's shortcut.
- Full Keyboard Access reaches source controls, results, actions, and preview.
- Closing returns focus to the destination when it is still valid.

### General rules

- Use native focus rings for fields and native list-row highlight for results.
- Avoid moving focus without a user action.
- Preserve a logical, stable Tab order.
- Do not trap focus in a transient panel.
- Respect standard macOS shortcuts and allow Koru-specific global shortcuts to be changed.

Apple recommends system-provided focus effects and warns against changing focus without user interaction in [Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection/). Apple's [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards) guidance also recommends respecting standard shortcuts and testing Full Keyboard Access.

## 6. Accessibility requirements

### 6.1 VoiceOver

VoiceOver must announce:

- “Koru suggestions” or “Koru recall” when the panel becomes available;
- active source;
- result count;
- focused result preview summary, source/type, and position;
- whether insertion replaces the exact matched tag, an active selection, or inserts at the caret;
- save-editor content and trigger-tag validation;
- permission, unavailable, and fallback states;
- completion of Save or Insert without reading private content unnecessarily.

Avoid announcing the full contents of a long or potentially sensitive saved item automatically. Provide an explicit Read Preview action.

### 6.2 Keyboard-only use

Every core action must be possible without a pointer:

- open recall;
- switch source;
- search and navigate;
- preview and select;
- choose insertion mode;
- save selection;
- create and edit exact trigger tags;
- edit, archive, restore, delete, clear, and export;
- open permission repair and settings.

### 6.3 Visual access

- Support Increase Contrast.
- Support Reduce Transparency.
- Maintain visible focus in light and dark appearances.
- Ensure text and essential icons meet the contrast of the system semantic colors they use.
- Avoid meaning conveyed only by hue, transparency, or subtle shadow.
- Do not clip essential text at supported larger display/text settings.

### 6.4 Motion

- Respect Reduce Motion.
- Use only short, functional appearance and dismissal transitions.
- Do not animate panel position continuously with every caret movement.
- Avoid scale, bounce, or spring effects for routine recall.
- Never delay interaction until animation completes.

### 6.5 Motor and pointer access

- Core actions have keyboard alternatives.
- The save icon's visual size may be compact, but its activation region must meet macOS target guidance and avoid overlapping destination controls.
- Do not require precise hover to reveal the only route to an action.
- Context menus have visible or keyboard-accessible equivalents for essential actions.

### 6.6 Cognitive accessibility

- Use consistent terms: Saved, Clipboard, Saved item, content, trigger tag.
- Keep each transient surface focused on one decision.
- Do not auto-dismiss forms or validation messages on a timer.
- Avoid teaching a large shortcut grammar before first value.
- Explain permission consequences in plain language before asking.

Apple advises simple, familiar interactions, alternatives to gestures, support for assistive technologies, and avoiding time-boxed controls in [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/).

## 7. Content and copy system

### Voice

- concise;
- direct;
- calm;
- factual about privacy and failure;
- never promotional inside the utility.

### Vocabulary

Use:

- Saved
- Clipboard
- Saved item
- Trigger tag
- Content
- Save selection
- Insert
- Copy
- Open Settings

Avoid as core UI:

- Prompt vault
- AI memory
- Magic replacement
- Smart paste
- Knowledge base
- Train Koru

### Copy patterns

| Situation | Recommended copy |
| --- | --- |
| No saved match | No saved matches |
| Empty clipboard | Clipboard history is empty |
| Clipboard paused | Clipboard history is paused |
| Destination changed | The writing location changed. Copy instead? |
| Permission missing | Koru needs Accessibility access to insert here. |
| Missing file | The original file is no longer available. |
| Duplicate | This text is already saved. |
| Save success | Saved to Koru |

Avoid exclamation marks, blame, internal error codes, or claims that content is safe when Koru cannot verify the source context.

## 8. Accessibility and design QA matrix

Every release candidate must be checked with:

- light and dark appearance;
- Increase Contrast;
- Reduce Transparency;
- Reduce Motion;
- Full Keyboard Access;
- VoiceOver;
- keyboard-only recall, capture, tag editing, library, and settings flows;
- multiple displays and screen edges;
- common text scaling/display configurations;
- secure fields and applications where macOS Secure Input or host capabilities limit integration;
- no-caret-bounds fallback;
- empty, loading, permission, unavailable, and failure states.

Use Accessibility Inspector to inspect the exposed hierarchy, names, values, roles, actions, and focus order. Apple recommends Accessibility Inspector as part of interface auditing in [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/).

## 9. UX acceptance criteria

- [ ] The design feels native and visually subordinate to the destination app.
- [ ] The everyday panel is compact and contains no management-heavy UI.
- [ ] Light is the primary visual direction, with complete system dark-mode support.
- [ ] System typography remains legible and adaptable; essential content is never set at the minimum size.
- [ ] Focus and selection are visibly distinct.
- [ ] Saved and Clipboard are distinguishable without color alone.
- [ ] Every icon-only core action has a label, tooltip, and keyboard alternative.
- [ ] Save, insertion, and destructive actions are explicit.
- [ ] Reduced motion/transparency and increased contrast are respected.
- [ ] VoiceOver and Full Keyboard Access complete every core flow.
- [ ] No exact visual mock, brand palette, or decorative system is treated as approved by this document.

## References

- [Apple Human Interface Guidelines: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/)
- [Apple Human Interface Guidelines: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/)
- [Apple Human Interface Guidelines: Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection/)
- [Apple Human Interface Guidelines: Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards)
- [Apple Developer Documentation: Accessibility for AppKit](https://developer.apple.com/documentation/appkit/accessibility-for-appkit)
