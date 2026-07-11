# Koru Product Vision and Principles

## Product definition

Koru is a free, open-source, native macOS writing memory. It helps people keep useful writing, recall it from an imperfect fragment, and insert it beside the caret without leaving the app where they are working.

Koru has two deliberately different memory layers:

- **Saved** is permanent and intentional. It contains reusable saved items.
- **Clipboard** is temporary and automatic. It contains recently copied text and other supported pasteboard content.

The product is not centered on prompts. Prompts are one use case alongside recurring messages, code commands, addresses, support replies, checklists, and reusable writing templates.

## Vision

Make anything worth writing twice available at the point of writing, without requiring people to remember where they saved it or the exact shortcut they assigned to it.

## Product promise

> Remember a fragment. See the right item. Choose it. Keep writing.

Koru succeeds when it feels less like opening another application and more like macOS quietly remembering useful work.

## The problem

The macOS text-replacement model is useful for exact, known pairs, but the system workflow is built around a manually configured **Replace / With** pair. A person who forgets the replacement key has no recall surface at the caret, and the settings UI is separated from the moment when useful text is created. Apple documents this exact-pair workflow in [Replace text and punctuation in documents on Mac](https://support.apple.com/guide/mac-help/mh35735/mac).

Existing products prove demand but also define a crowded category. Raycast already offers both [Snippets](https://manual.raycast.com/snippets) and [Clipboard History](https://manual.raycast.com/clipboard-history), while TextExpander offers [inline snippet search](https://textexpander.com/learn/using/searching-snippets). Koru therefore cannot win by being only a snippet manager, prompt organizer, or clipboard history.

Koru's focused difference is the complete loop:

1. Capture useful writing where it is created.
2. Recall it from whatever initial fragment comes to mind.
3. Preview and explicitly select the intended result.
4. Insert it beside the caret.
5. Keep permanent saved items visibly separate from temporary clipboard history.

## Primary audience

Koru is initially for individual Mac users who write repeatedly across several applications, especially:

- developers and technical operators;
- founders and product professionals;
- marketers, consultants, salespeople, and support professionals;
- people who use AI assistants and reuse instructions across different tools;
- anyone currently keeping repeated writing in Notes, documents, chat history, or an informal collection of keyboard replacements.

The primary audience values speed and keyboard control but should not need to be a macOS power user to understand the product.

## Jobs to be done

1. **Recall:** When I remember only part of something useful, help me find it without leaving the field where I am writing.
2. **Capture:** When I have just written something worth keeping, let me save it before I send, submit, or lose it.
3. **Reuse:** When I choose a saved item, insert it predictably without changing any other text.
4. **Adapt:** When reusable writing contains changing values, let me complete those values before insertion.
5. **Recover:** When I need something copied earlier, show a compact, searchable list of recent clipboard items beside my current task.
6. **Trust:** Keep my writing on my Mac, avoid secure contexts, and make every text-changing action explicit.

## Product principles

### 1. Writing remains untouched until the user acts

Automatic typed matching may surface suggestions only after a qualifying fragment is typed during an eligible fresh, empty input session at the beginning of the field. Merely focusing an empty field never opens Koru, and matching never activates in the middle of established writing. The typed characters remain exactly as entered until the user explicitly selects a result.

There is no silent replacement, background rewriting, or automatic prompt improvement.

### 2. Recall beats memorization

People should be able to type an imperfect fragment such as `pus` and see relevant saved items such as “Push to GitHub.” Exact aliases can improve ranking, but they are not required for basic recall.

### 3. Capture at the point of value

Koru should make the useful moment easy to preserve. Selecting all text may reveal a tiny optional save icon; keyboard, menu-bar, and macOS Service entry points remain available, while actual capture depends on the host exposing the selection through a supported path.

### 4. Permanent and temporary memory stay distinct

Saved items are deliberately kept. Clipboard entries expire according to local retention settings. Keeping clipboard content permanently is an explicit save action that creates a separate saved item; it does not pin or extend the original temporary entry.

### 5. Explicit action is better than clever automation

Koru can rank, filter, and remember local usage signals, but it must not guess that the user wants text changed. Focus and selection are separate states; selection requires a distinct action, consistent with Apple's [focus and selection guidance](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection/).

### 6. Native, momentary, and calm

The everyday experience is a compact macOS surface near the caret, not a dashboard. It uses current native conventions, system materials, standard focus behavior, and familiar keyboard interactions. Apple recommends platform-consistent focus effects and keyboard shortcuts in its [macOS design guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/).

### 7. Local first means useful without an account

Core capture, recall, clipboard history, search, and insertion work locally without sign-in or a network connection. Content is never required to leave the Mac. Any diagnostics that leave the device are content-free, optional, and clearly explained.

### 8. Neutral vocabulary keeps the product broad

The permanent object is a **saved item**. A saved item can behave as:

- **Saved text** — reusable content recalled through search;
- **Quick replacement** — reusable content with strong initial match terms;
- **Template** — reusable content with values completed before insertion.

“Prompt” may appear in examples and onboarding use cases, but not as the product's primary navigation or data model.

### 9. Open source includes data freedom

Koru is free and open source. Users can inspect the implementation, export their saved items in a documented format, and leave without losing their writing.

### 10. Accessibility is part of speed

Every core action supports keyboard-only use, visible focus, VoiceOver labels, sufficient contrast, reduced motion, and a non-pointer alternative. Apple's accessibility guidance specifically recommends Full Keyboard Access, appropriately labeled controls, and alternatives to gesture-only interaction in [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/).

## Product boundaries

Koru is:

- a writing-memory utility;
- a local saved-item library;
- a temporary mixed-content clipboard history;
- a caret-adjacent recall and insertion surface;
- a lightweight capture flow.

Koru is not:

- an AI writing assistant;
- a prompt marketplace or prompt-engineering product;
- a general macOS launcher;
- a macro or workflow automation engine;
- a cloud knowledge base;
- a permanent archive of every copied file;
- an invisible keystroke logger;
- a tool that replaces text without confirmation.

## Product decision test

A proposed feature belongs in Koru only when it makes at least one part of capture, recall, selection, insertion, or trust materially better without making the everyday surface heavier.

If a feature mainly creates content, automates other applications, adds hierarchy, or encourages passive collection, it should remain outside the core product.

## References

- [Apple Support: Replace text and punctuation in documents on Mac](https://support.apple.com/guide/mac-help/mh35735/mac)
- [Apple Human Interface Guidelines: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/)
- [Apple Human Interface Guidelines: Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection/)
- [Apple Human Interface Guidelines: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/)
- [Raycast Manual: Snippets](https://manual.raycast.com/snippets)
- [Raycast Manual: Clipboard History](https://manual.raycast.com/clipboard-history)
- [TextExpander: Searching Snippets](https://textexpander.com/learn/using/searching-snippets)
