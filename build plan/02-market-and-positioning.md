# Koru market and positioning

Status: product decision document
Research checked: 2026-07-11
Scope: native macOS product, public repository at builderking/koru

## Decision

Koru will enter the market as **local writing memory for macOS**.

It is not positioned as a better text expander, a generic prompt library, or a feature-heavy clipboard manager. Those categories are mature. Koru's wedge is removing the boundary between two storage layers people currently search separately:

1. permanent saved items, each of which can behave as Saved text, a Quick replacement, or a Template;
2. recent clipboard material that is useful now but may not deserve permanent storage.

Both layers are recalled from beside the caret where the target exposes reliable bounds, with a stable fallback elsewhere. At position zero in a fresh empty input, the user can begin typing a matching fragment; the interface appears only when the fragment matches. The global hotkey can open Koru immediately where macOS permits. Selected writing can be captured before it is sent or replaced when the host exposes it through Accessibility or Services. The core remains local and understandable.

The shortest category statement is:

> Koru remembers your writing where you write.

The clearest product explanation is:

> Koru brings saved writing, reusable templates, and recent clipboard items to the caret, locally on your Mac.

## The market truth

The underlying needs are already validated, but the workflow is fragmented.

| Product or platform | What it already does well | What that means for Koru |
| --- | --- | --- |
| Apple Text Replacements | Simple replace/with pairs, iCloud sync, and import/export. Apple notes that replacements work in many, not all, apps. | Exact abbreviation expansion is table stakes and cannot be Koru's main claim. |
| macOS Spotlight Clipboard History | Current macOS can search text, images, links, and files from clipboard history through Spotlight. | Clipboard history itself is now an operating-system baseline. Koru must be faster in the writing context and connect temporary material to permanent memory. |
| Typinator | Markets directly as an AI prompt manager, supports prompt triggers, fields, quick search, local storage, and shared sets. | “Prompt manager for Mac” is occupied positioning. Prompt support is a use case inside Koru, not its category. |
| TextExpander | Exact expansion, inline search near the cursor, forms and macros, creation from clipboard, and repeated-writing suggestions. | Inline snippet search and repetition detection are not unique. Koru must win on unified recall, low-friction capture, and partial memory. |
| Raycast | Combines snippets with a rich clipboard history, search, pinning, tags, OCR, and save-as-snippet actions. | A unified feature list is insufficient. Koru must feel native to the active writing surface rather than like a general command launcher. |
| Alfred | Combines clipboard history, snippets, merging, and actions that save selected text as a snippet. | Selection capture is proven but not unique. Koru should make it a primary, one-step writing loop. |
| Paste | Deep clipboard search, filters, pinboards, OCR, editing, multi-paste, iCloud sync, and an MCP integration. | Koru should not compete on being the most exhaustive clipboard archive. Temporary recall should be intentionally bounded and promotable. |
| PastePal | Offers a cursor popup, filters, queue workflows, and iCloud sync. | Cursor proximity alone is not a defensible claim. Koru also needs unified permanent-and-temporary recall and fragment-first retrieval. |
| Espanso | Free and open-source cross-platform expansion with search, forms, scripts, packages, and file-based configuration. | Open source and exact triggers are not sufficient differentiation. Koru's advantage should be native macOS interaction and a polished non-technical workflow. |

### Sources

- Apple, [Replace text and punctuation in documents on Mac](https://support.apple.com/en-gb/guide/mac-help/mh35735/mac)
- Apple, [Back up and share text replacements](https://support.apple.com/en-lamr/guide/mac-help/mchl2a7bd795/mac)
- Apple, [Search your clipboard history](https://support.apple.com/guide/mac-help/search-your-clipboard-history-mchl40d5b86b/mac)
- Typinator, [AI prompt manager for Mac](https://ergonis.com/en/typinator/ai-prompts/)
- Typinator, [Features](https://ergonis.com/en/typinator/features/)
- TextExpander, [Inline Search](https://textexpander.com/learn/using/searching-snippets)
- TextExpander, [Suggested snippets](https://textexpander.com/learn/using/snippets/create/suggested-snippets)
- Raycast, [Snippets](https://manual.raycast.com/snippets)
- Raycast, [Clipboard History](https://manual.raycast.com/clipboard-history)
- Alfred, [Clipboard History](https://www.alfredapp.com/help/features/clipboard/)
- Alfred, [Universal Actions](https://www.alfredapp.com/help/features/universal-actions/)
- Paste, [Product overview](https://pasteapp.io/)
- PastePal, [Mac App Store listing](https://apps.apple.com/us/app/clipboard-manager-pastepal/id1503446680?platform=mac)
- Espanso, [Product overview](https://espanso.org/)

Market facts and competitor capabilities change. Recheck this source ledger before publishing comparison copy or launch claims.

## Where current products still fall short

### 1. They organize by tool, not by the user's memory

A person often remembers a fragment such as “push…” or “the review prompt about security,” not which application, folder, abbreviation, pinboard, or snippet set contains it. Existing tools frequently require the user to remember the system used to save the item before searching for the item itself.

Koru should search one writing-memory surface first and reveal whether the result is a permanent saved item or temporary Recent entry second.

### 2. Exact triggers become another memory burden

Abbreviations are fast only when remembered exactly. Large libraries turn into private command languages that users forget. Search overlays help, but they commonly begin after the user remembers a separate keyboard shortcut.

Koru should accept imperfect fragments, match terms, words from the body, and recent context. Exact triggers remain an accelerator, not a prerequisite.

### 3. Clipboard history is temporary but treated as a separate destination

Clipboard products are good at retaining and searching. Snippet products are good at permanent reuse. The promotion path between them is often hidden behind menus or a different mode.

In Koru, a clipboard item should be usable immediately and promotable to a saved item without leaving the caret-side surface.

### 4. Capturing good writing happens too late

People frequently compose the useful answer first, then send or overwrite it, and only later realize it should have been saved. A library-centric product expects users to stop, open the library, create a record, name it, and return.

Koru should let users select the text they just wrote and save it in one deliberate action before they use it.

### 5. General launchers are broad by design

Raycast and Alfred are powerful because they cover many jobs. That breadth necessarily places writing reuse inside a larger command model.

Koru should be narrower: activate at the writing surface, show only writing-relevant actions, and disappear immediately after insertion.

### 6. Privacy is often an assurance, not a visible model

Clipboard and prompt content can include credentials, personal messages, client information, and unpublished work. “Local” is most trustworthy when users can see exclusions, retention, storage location, pause controls, and deletion behavior.

Koru should make those controls part of the product, not only a privacy policy.

## Primary audience

The launch audience is people who write repeatedly across multiple Mac applications and already feel the cost of losing or recreating useful language:

- developers repeating prompts, shell instructions, review checklists, release notes, and Git workflows;
- founders and operators repeating customer replies, product briefs, hiring notes, and support answers;
- designers and product managers repeating research prompts, handoff language, acceptance criteria, and feedback;
- writers and consultants reusing outlines, tone instructions, clauses, and client-specific material;
- heavy AI-tool users whose most valuable prompts are scattered among chats, notes, clipboard history, and text replacements.

The audience is not “everyone who types” at launch. Koru should first serve people with enough repeated writing that recall failure is already painful.

## Jobs to be done

### Recall

> When I remember only part of something useful I wrote before, help me find it from where I am typing so I can continue without changing tools.

### Reuse

> When I repeatedly type the same instruction, response, or prompt, let me insert the trusted version quickly without memorizing a rigid code.

### Rescue

> When I copied something recently and need it again, show it beside the caret without making me search a separate clipboard application.

### Preserve

> When I have just written something worth reusing, let me save it before I send, replace, or lose it.

### Trust

> When my writing may be sensitive, let me understand what Koru stored, where it lives, how long it remains, and how to remove or exclude it.

## The product wedge

Five behaviors form the launch wedge. Removing any one makes Koru easier to compare with an existing category.

1. **One recall surface:** permanent saved items and recent clipboard entries appear in one ranked result list; a saved item's behavior may be Saved text, Quick replacement, or Template.
2. **Fragment-first retrieval:** a user can type or search with the words they remember; exact triggers are optional accelerators.
3. **Start where writing starts without interruption:** when the user types a matching fragment at position zero in a fresh empty input, Koru may appear. It never opens merely because the field is empty. The hotkey remains the immediate manual path.
4. **Capture before use:** selected writing can be saved in one step and then left in place, copied, or used normally.
5. **Local, inspectable memory:** core storage and ranking work without an account or cloud dependency, with visible exclusions and deletion.

This wedge is more important than an exhaustive feature checklist. Koru should initially do these five things exceptionally well across a verified set of Mac applications.

## One permanent model and one temporary layer

The product should explain its model in ordinary language:

| Product term | Meaning | Default behavior |
| --- | --- | --- |
| **Saved item** | One permanent object for writing the user intentionally keeps. Its behavior is Saved text, Quick replacement, or Template. | Remains until edited or deleted. Searchable by title, match terms, tags, and body. |
| **Recent clipboard entry** | Separate temporary material captured for short-term recall. | Expires under a visible retention policy. Saving it creates a separate permanent saved item without extending the temporary entry. |

Behaviors and temporary status should remain visually legible in results, but users should never need to choose a database before searching.

“Prompt” is a supported item purpose, not a separate storage silo. A saved item may be a prompt, response, command, paragraph, address, checklist, or template.

## Positioning statement

For Mac users who repeatedly write and reuse valuable text across applications, Koru is a local writing-memory utility that recalls saved writing, quick templates, and recent clipboard material beside the caret. Unlike exact-only text expanders, standalone prompt libraries, clipboard archives, and general launchers, Koru starts from what the user remembers, even an imperfect fragment, and makes preserving the current selection part of the same flow.

## Messaging hierarchy

### Category

Local writing memory for macOS.

### Promise

Remember what you meant, even when you only remember a fragment.

### Explanation

Saved writing, reusable templates, and recent clipboard items, recalled beside the caret.

### Proof

- Find from a partial phrase, title, match term, or body word.
- Type a matching fragment at position zero in a fresh input, or use the hotkey for immediate browsing.
- Insert without leaving the application.
- Save selected writing before it disappears.
- See and control what is stored locally.
- Inspect the source code.

### Emotional benefit

Stop rebuilding language you already worked to get right.

## Launch scenarios

### Imperfect prompt recall

A developer remembers “push…” but not the abbreviation or title. Koru ranks “Push to GitHub safely” and shows its saved status and optional trigger. The user explicitly chooses it, and only then does Koru insert it. The marketing claim is recall from a remembered fragment, not the literal example trigger “Pus.”

### Clipboard rescue

A user activates Koru in a text field and searches recent items for a filename, link, image, or copied paragraph. The item appears in the same surface as saved writing. If it will matter later, the user promotes it to Saved.

The V1 default “clp” is a locked clipboard-scope trigger when typed at position zero in a fresh empty input. It must still require explicit item choice, never silently replace text, and may become configurable after V1. The global hotkey remains the manual fallback where macOS permits.

### Capture before sending

A user finishes a strong response, selects it, invokes Koru, and chooses Save selection. Koru proposes a title and keeps the original text untouched. Saving should not require opening the library first.

### Start with a remembered fragment

At position zero in a fresh empty input, the user begins typing a fragment such as “pus.” Koru appears only after that fragment matches and shows relevant saved items. It never opens merely because the field is empty. If the user wants to browse before typing, the global hotkey opens the same surface immediately.

## Competitive boundaries and honest claims

Koru may claim:

- one caret-side surface across permanent saved items and temporary Recent clipboard entries;
- recall from imperfect fragments, subject to measured quality;
- local-first core behavior without an account;
- intentional selection capture and clipboard promotion;
- a focused native macOS workflow;
- free and open-source availability under Apache-2.0 once repository files are present.

Koru must not claim:

- to be the first prompt manager, cursor popup, text expander, clipboard history, or selected-text capture tool;
- that it works in every Mac application;
- that local storage alone makes it secure;
- that no data ever leaves the Mac if the website, update mechanism, crash reporting, or optional future services behave otherwise;
- semantic or AI recall until a shipped local implementation has been evaluated;
- support for images or videos until the specific pasteboard types, size limits, persistence, and insertion behavior are verified;
- better speed or accuracy than competitors without a reproducible benchmark.

## Why open source helps the position

Open source is a trust mechanism and distribution advantage, not the entire product strategy:

- users can inspect capture, storage, exclusion, and network behavior;
- contributors can verify compatibility across applications;
- a public issue tracker can expose limitations rather than hiding them;
- local-first behavior remains useful even if hosted services or the marketing site disappear.

It does not remove the need for signing, notarization, dependency review, secure updates, or clear governance.

## Product principles derived from the market

1. **Recall beats filing.** Saving structure must not become a prerequisite to finding.
2. **Exact triggers are shortcuts, not passwords.**
3. **Temporary and permanent memory must have an obvious bridge.**
4. **The surface should appear at the work, not become a new workspace.**
5. **Privacy controls must be visible at the moment they matter.**
6. **Native simplicity is a feature boundary.**
7. **Ship verified compatibility, not universal claims.**
8. **Do not add AI merely to use the word AI.** Local lexical and fuzzy retrieval should establish the interaction before optional local semantic ranking is considered.

## Signals that the wedge is working

The beta should collect local, opt-in or user-reported evidence rather than default behavioral telemetry.

- users retrieve an item without remembering its exact title or trigger;
- saved-selection capture leads to later reuse;
- recent clipboard items are sometimes promoted rather than accumulating forever;
- users successfully trigger Koru from a matching fragment at position zero in a fresh input, and use the hotkey when they want immediate browsing;
- false activations remain rare enough that users leave the feature enabled;
- users can explain that Saved text, Quick replacement, and Template are behaviors of one permanent saved item, while Recent clipboard entries are temporary;
- users trust exclusions and retention because they can inspect and test them;
- users replace a multi-tool workflow, not merely duplicate one more utility.

## Positioning decisions still to validate

- Whether “writing memory” is immediately understandable without explanation.
- Whether “Koru” can be used respectfully, legally, and globally as the product brand.
- Whether the first audience should be described as developers and AI power users or as cross-functional Mac professionals.
- Whether “beside the caret” is reliable enough across the launch application matrix to remain the headline.
- Whether partial lexical recall is sufficient for version one or users truly need a local semantic model.

These are validation questions, not reasons to broaden the first build.
