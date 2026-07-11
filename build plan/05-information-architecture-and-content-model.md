# Koru Information Architecture and Content Model

## 1. Information-architecture objective

Koru should feel like one writing memory with two clearly different sources:

- **Saved** — permanent, intentional, user-managed;
- **Clipboard** — temporary, automatic, retention-managed.

The interface must not create separate top-level products for prompts, snippets, text replacements, and templates. Those labels describe use cases or saved-item behavior, not competing libraries.

## 2. Primary surfaces

### 2.1 Recall panel

The recall panel is Koru's primary everyday surface.

It contains:

- current source: Saved, Clipboard, or All when manually invoked;
- query or reflected initial fragment;
- compact ranked results;
- result preview and type/behavior metadata;
- insertion alternatives when relevant;
- entry points to Save, Edit, Library, or Settings only when needed.

It is ephemeral, caret-adjacent, and optimized for keyboard selection. It is not a miniature library-management window.

### 2.2 Save popover

The save popover appears from:

- optional select-all save icon;
- Save Selection shortcut or menu command;
- Save action on a clipboard result;
- Create Saved Item from the library.

It contains only the fields needed for the selected behavior. Advanced metadata remains collapsed or in the library editor.

### 2.3 Template completion surface

This surface appears only after a Template result is explicitly chosen. It collects field values, previews rendered text, and confirms insertion. It does not edit the template definition unless the user explicitly enters Edit Template.

### 2.4 Library window

The library is the deliberate management surface.

Recommended top-level destinations:

1. **Saved** — active permanent items;
2. **Clipboard** — temporary history and storage status;
3. **Archive** — saved items removed from ordinary recall;
4. **Recently Deleted** — recoverable saved items during the configured recovery window.

Settings opens as a standard app settings window or settings destination, not as a content library.

### 2.5 Menu-bar menu

The menu-bar surface communicates state and gives direct access to:

- Open Recall;
- Save Selection;
- Open Library;
- pause/resume Clipboard;
- Full mode / Hotkey-only mode status;
- permission-health status;
- Settings;
- Quit.

The menu-bar icon must not become a live content browser.

### 2.6 Settings

Recommended settings groups:

- **General:** launch at login, appearance, default insertion mode;
- **Recall:** manual shortcut, initial typed matching, per-app exclusions, result behavior;
- **Clipboard:** enablement, retention, storage, content limits, exclusions, clear actions;
- **Privacy:** local-data location, diagnostics consent, sensitive-content behavior;
- **Shortcuts:** configurable commands and conflict state;
- **Data:** import, export, backup, restore, reset;
- **Permissions:** active capability status and repair actions;
- **Accessibility:** motion/visual overrides only where system settings are insufficient.

## 3. Navigation model

Routine path:

```text
Current text field -> Recall panel -> Select -> Insert -> Current text field
```

Capture path:

```text
Selected text or Clipboard entry -> Save popover -> Saved item
```

Management path:

```text
Menu bar or panel -> Library -> Saved / Clipboard / Archive / Recently Deleted
```

The recall panel should never require navigation through a folder tree. Search and ranking are primary; tags and archive are supporting organization.

## 4. Permanent content model

### 4.1 `SavedItem`

`SavedItem` is the only permanent reusable-content entity.

| Field | Purpose |
| --- | --- |
| `id` | Stable local identifier. |
| `schemaVersion` | Supports migrations and portable export. |
| `title` | User-facing recall label. Required. |
| `behavior` | `savedText`, `quickReplacement`, or `template`. |
| `plainContent` | Canonical plain-text representation. Required when the item is textual. |
| `richContent` | Optional supported attributed representation. |
| `assetReferences` | Optional local references for supported saved assets. |
| `matchTerms` | Optional explicit terms; at least one is required for Quick replacement. |
| `tags` | Optional flat labels. |
| `templateFields` | Ordered field definitions for Template behavior. |
| `pinned` | Promotes the item in recall ordering. |
| `archivedAt` | Removes item from ordinary recall without deletion. |
| `createdAt` | Local creation timestamp. |
| `updatedAt` | Local modification timestamp. |
| `lastUsedAt` | Local recency signal. |
| `useCount` | Local frequency signal. |
| `sourceContext` | Optional user-visible origin such as source app or “Saved from Clipboard.” |
| `contentHash` | Keyed local digest that supports duplicate detection without persisting a raw content hash. |

“Prompt” is not a `SavedItem` behavior. A prompt can be Saved text, Quick replacement, or Template depending on how it is reused.

### 4.2 Behavior semantics

#### Saved text

- Minimal permanent item.
- Searchable by title, content, tags, and learned local recall signals.
- Inserted only after explicit selection.

#### Quick replacement

- Adds one or more preferred initial match terms.
- Receives stronger ranking when an initial fragment matches those terms.
- Does not automatically replace the fragment; selection is still required.

#### Template

- Contains ordered fields.
- Opens completion before insertion.
- Stores the template definition, not completed values by default.

Behavior is editable. Changing behavior does not create a separate item unless the user chooses Duplicate.

### 4.3 `TemplateField`

| Field | Purpose |
| --- | --- |
| `id` | Stable field identifier within the template. |
| `token` | Placeholder token used in canonical content. |
| `label` | Human-readable field name. |
| `helpText` | Optional concise clarification. |
| `required` | Whether insertion requires a value. |
| `defaultValue` | Optional local default. |
| `order` | Completion and keyboard-navigation order. |
| `inputType` | Initial scope: single-line or multiline text. |

The initial release should not add complex field logic, external data lookup, or executable expressions.

### 4.4 `RecallSignal`

This local-only supporting entity improves recall without requiring memorized aliases.

| Field | Purpose |
| --- | --- |
| `normalizedQuery` | The fragment or panel query, normalized locally. |
| `savedItemID` | The item explicitly chosen for that query. |
| `selectionCount` | Strength of the learned relationship. |
| `lastSelectedAt` | Recency signal. |
| `destinationAppID` | Optional local app context; never required for a match. |

Recall signals are sensitive local usage metadata because a normalized query can reflect what the user typed. They are encrypted, do not leave the Mac, and can be reset independently. They influence ranking but never cause automatic insertion.

## 5. Temporary clipboard content model

### 5.1 `ClipboardEntry`

| Field | Purpose |
| --- | --- |
| `id` | Stable identifier for the retained entry. |
| `capturedAt` | Capture timestamp used for recency. |
| `expiresAt` | Calculated local expiry. |
| `sourceAppID` | Best-effort frontmost application observed around the pasteboard change, when retained; never treated as authoritative source attribution. |
| `representations` | Supported pasteboard/UTType representations. |
| `plainText` | Canonical text when directly provided; encrypted at rest and indexed only in memory after vault unlock. |
| `displayTitle` | Safe derived label such as first line or file name. |
| `previewReference` | Local text preview or generated thumbnail. |
| `fileReference` | Reference to an external file when content is not copied into Koru. |
| `byteSize` | Storage and limit accounting. |
| `contentHash` | Keyed local digest for duplicate/coalescing support. |
| `availability` | Available, expired, missing source file, unsupported, or skipped. |

Apple defines `NSPasteboard` as the macOS interface to the shared pasteboard server and notes that a pasteboard can contain multiple items and representations. Koru must preserve that distinction rather than flattening every entry to text. See [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard).

This is a logical model. Sensitive fields, titles, previews, application context, file references, and payloads are encrypted in persistent storage; searchable plaintext exists only in the bounded in-memory index.

### 5.2 Supported initial representation classes

- plain text;
- attributed/rich text where safely retained;
- URL;
- image;
- file reference, including a video file copied in Finder;
- unsupported representation metadata sufficient to explain why it was skipped.

Koru does not initially archive large video binaries. A file row must say when it is a reference whose availability depends on the source file.

### 5.3 Permanent promotion

Saving a Clipboard entry creates a `SavedItem` through the normal save flow.

The operation:

- chooses an appropriate representation;
- requires a title and behavior confirmation;
- creates a new permanent identifier;
- leaves the temporary entry under its existing retention rules;
- records “Saved from Clipboard” only as optional origin context.

Clipboard entries do not become permanent through a generic Pin action.

## 6. Search and ranking architecture

### 6.1 Saved search index

Searchable fields:

- title;
- explicit match terms;
- tags;
- plain content;
- template field labels;
- locally learned query relationships.

Recommended ranking order:

1. exact explicit match term;
2. prefix match on explicit match term;
3. exact or prefix title-token match;
4. repeated local query-to-item selection;
5. pinned state;
6. previous use in the destination application;
7. general recency and frequency;
8. fuzzy title or content match.

Ranking is deterministic enough to explain. The panel may show “Matched title,” “Match term,” or “Recently used here” in details, but should not add copy to every row.

### 6.2 Clipboard search index

Searchable fields in the initial scope:

- provided plain text;
- URL text;
- file name and available file metadata;
- best-effort observed frontmost application label, when retained and clearly presented as context rather than proven source;
- safe derived display title.

Images without source text or metadata remain discoverable through recency and thumbnails. OCR is deferred and must not be implied by the search UI.

### 6.3 Mixed results

`clp` opens a single recent list with mixed content types. Manual All search may combine Saved and Clipboard, but each row must expose its source through text accessible to VoiceOver and a secondary visual cue.

Cross-source ranking must not let a transient clipboard duplicate displace an exact permanent match without a clear source indication.

## 7. Organization model

Initial organization is deliberately flat:

- title is required;
- behavior describes insertion behavior;
- match terms improve recall;
- tags are optional and flat;
- pinning is a small favorite set;
- archive removes inactive permanent items;
- local usage improves ordering.

Not included initially:

- nested folders;
- separate prompt libraries;
- projects with ownership or permissions;
- mandatory category selection;
- saved searches;
- public/shared catalogs.

## 8. Content lifecycle

### 8.1 Saved item

```text
Draft -> Active -> Archived -> Recently Deleted -> Permanently Deleted
```

- Draft exists only inside an unfinished save/edit flow.
- Active appears in ordinary recall.
- Archived is searchable only when Archive is included.
- Recently Deleted is recoverable during the configured recovery window.
- Permanently Deleted is removed from the local store and subsequent exports.

### 8.2 Clipboard entry

```text
Observed -> Retained -> Expired or Cleared
                   \-> Explicit Save -> New SavedItem
```

- Observed content is validated against secure/transient types and limits.
- Retained content is available in Clipboard.
- Expiry is controlled by age and storage policy.
- Clear removes local retained data according to the chosen scope.
- Save creates a separate permanent object.

## 9. Display-content rules

- Prefer the user title for saved items.
- When no safe clipboard title exists, use a compact type label and age, not invented meaning.
- Truncate previews visually without modifying stored content.
- Mask sensitive-looking previews only when the user enables such local masking; masking is not a substitute for secure-field exclusion.
- Rich content always has a plain-text fallback when one is available.
- File-reference rows clearly distinguish reference from locally retained asset.
- Timestamps use relative time in the panel and exact time in item details.
- Errors describe the object and recovery action, not internal pasteboard types or implementation details.

## 10. Import, export, and migration

### Export

- Permanent saved items export by default.
- Temporary clipboard history requires a separate explicit export action.
- Text metadata uses a documented human-inspectable format.
- Assets are included in a documented sibling directory when selected.
- Export includes schema version and behavior semantics.
- Local recall signals are excluded by default because they are incidental usage history.

### Import

- Validate schema and content before writing.
- Preview item count, behaviors, conflicts, and skipped assets.
- Never overwrite by title alone.
- Match stable IDs and hashes when available.
- Offer Keep both, Update, or Skip for conflicts.

### Migration

- Every local database migration is versioned and reversible through a pre-migration backup.
- A failed migration preserves the previous readable store and explains recovery.
- The open-source repository documents breaking export-format changes.

## 11. Privacy boundaries in the IA

- Secure/protected contexts do not enter any content model.
- Clipboard changes observed while an excluded app is frontmost create no entry, and excluded apps create no initial-match recall signal. Koru does not claim authoritative clipboard-source attribution when macOS does not expose it.
- Diagnostic state is modeled separately from user content.
- Clearing Clipboard does not delete Saved.
- Resetting learned recall signals does not delete Saved or Clipboard.
- Deleting Saved does not retroactively remove unrelated Clipboard entries, but exact duplicates are made visible during deletion when useful.
- No navigation label implies cloud storage, synchronization, or an account when those capabilities do not exist.

## 12. Information-architecture acceptance criteria

- [ ] The top-level permanent object is always called a saved item.
- [ ] Saved item behaviors are Saved text, Quick replacement, and Template.
- [ ] Prompt is treated as a use case, not a destination or schema type.
- [ ] Saved and Clipboard have distinct lifecycle, navigation, and source labels.
- [ ] Everyday recall does not require opening Library or navigating folders.
- [ ] `clp` can present text, URL, image, and file-reference rows in one list.
- [ ] Saving from Clipboard creates a permanent saved item.
- [ ] Search behavior does not imply OCR when OCR is unavailable.
- [ ] Export is documented, portable, and permanent-content-first.
- [ ] Every source and state is understandable by VoiceOver without color alone.

## References

- [Apple Developer Documentation: NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)
- [Apple Developer Documentation: Documents, Data, and Pasteboard](https://developer.apple.com/documentation/appkit/documents-data-and-pasteboard)
