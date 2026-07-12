# Koru Information Architecture and Content Model

## 1. Information-architecture objective

Koru should feel like one writing memory with two clearly different sources:

- **Saved** — permanent, intentional, user-managed;
- **Clipboard** — temporary, automatic, retention-managed.

The interface must not create separate top-level products for prompts, snippets, or text replacements. Those labels describe use cases for the same content-plus-tags saved item, not competing libraries.

## 2. Primary surfaces

### 2.1 Recall panel

The recall panel is Koru's primary everyday surface.

It contains:

- current source: Saved, Clipboard, or All when manually invoked;
- manual query or reflected exact matched tag;
- compact ranked results;
- result preview and source/type metadata;
- insertion alternatives when relevant;
- entry points to Save, Edit, Library, or Settings only when needed.

It is ephemeral, caret-adjacent, and optimized for keyboard selection. It is not a miniature library-management window.

### 2.2 Save popover

The save popover appears from:

- optional select-all save icon;
- Save Selection shortcut or menu command;
- Save action on a clipboard result;
- Create Saved Item from the library.

It contains the reusable content and one or more exact word-or-phrase tags. No title, behavior picker, match-term mode, or template editor is part of the canonical save surface.

### 2.3 Library window

The library is the deliberate management surface.

Recommended top-level destinations:

1. **Saved** — active permanent items;
2. **Clipboard** — temporary history and storage status;
3. **Archive** — saved items removed from ordinary recall;
4. **Recently Deleted** — recoverable saved items during the configured recovery window.

Settings opens as a standard app settings window or settings destination, not as a content library.

### 2.4 Menu-bar menu

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

### 2.5 Settings

Recommended settings groups:

- **General:** launch at login, appearance, default insertion mode;
- **Recall:** manual shortcut, automatic exact-tag matching, and result behavior;
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

The recall panel should never require navigation through a folder tree. Exact tags drive automatic recall; fuzzy tag/content search drives manual recall; archive supports organization.

## 4. Permanent content model

### 4.1 `SavedItem`

`SavedItem` is the only permanent reusable-content entity.

| Field | Purpose |
| --- | --- |
| `id` | Stable local identifier. |
| `schemaVersion` | Supports migrations and portable export. |
| `plainContent` | Canonical reusable text. Required. |
| `triggerTags` | One or more exact word-or-phrase tags assigned to the content. Required. |
| `pinned` | Promotes the item in recall ordering. |
| `archivedAt` | Removes item from ordinary recall without deletion. |
| `createdAt` | Local creation timestamp. |
| `updatedAt` | Local modification timestamp. |
| `lastUsedAt` | Local recency signal. |
| `useCount` | Local frequency signal. |
| `sourceContext` | Optional user-visible origin such as source app or “Saved from Clipboard.” |
| `contentHash` | Keyed local digest that supports duplicate detection without persisting a raw content hash. |

“Prompt,” “snippet,” and “replacement” are use cases, not `SavedItem` behaviors. A safe display title is derived at runtime from the first tag or first useful content line and is not a second user-authored field.

### 4.2 Saved-item semantics

- Minimal permanent item: content plus tags.
- Every tag is trimmed and compared case-, diacritic-, and width-insensitively for exact automatic matching.
- Internal spaces are preserved so a tag can be a phrase.
- Tags shorter than three user-perceived characters remain available to manual search but cannot open the automatic panel.
- The reserved `clp` tag cannot be assigned to saved content.
- Selecting a result is always required before any replacement.

### 4.3 `RecallSignal`

This local-only supporting entity improves fuzzy manual recall without changing automatic exact-tag eligibility.

| Field | Purpose |
| --- | --- |
| `normalizedQuery` | The fragment or panel query, normalized locally. |
| `savedItemID` | The item explicitly chosen for that query. |
| `selectionCount` | Strength of the learned relationship. |
| `lastSelectedAt` | Recency signal. |
| `destinationAppID` | Optional local app context; never required for a match. |

Recall signals are sensitive local usage metadata because a normalized manual query can reflect what the user typed in Koru. They are encrypted, do not leave the Mac, and can be reset independently. They influence manual ranking but never cause an automatic panel or insertion.

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
- requires reusable text and one or more tags;
- creates a new permanent identifier;
- leaves the temporary entry under its existing retention rules;
- records “Saved from Clipboard” only as optional origin context.

Clipboard entries do not become permanent through a generic Pin action.

## 6. Search and ranking architecture

### 6.1 Saved search index

Searchable fields:

- trigger tags;
- plain content;
- locally learned query relationships.

Automatic matching is a separate deterministic path:

1. inspect only the committed suffix immediately before the caret;
2. require a complete exact tag of at least three characters at a left boundary;
3. choose the longest matching tag when suffixes overlap;
4. return every active saved item assigned that tag;
5. never consult content, fuzzy distance, display title, or learned signals.

Recommended manual-recall ranking order:

1. exact tag;
2. prefix or contained tag;
3. exact or contained content;
4. repeated local query-to-item selection;
5. pinned state;
6. previous use in the destination application;
7. general recency and frequency;
8. deterministic fuzzy tag or content match.

Ranking is deterministic enough to explain. Manual recall may show “Matched tag,” “Matched content,” or “Recently used here” in details, but should not add copy to every row.

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

- content is required;
- one or more flat trigger tags are required;
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

- Derive a compact saved-item label from the first tag or first useful content line.
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
- Export includes schema version and trigger-tag semantics.
- Local recall signals are excluded by default because they are incidental usage history.

### Import

- Validate schema and content before writing.
- Preview item count, tags, conflicts, and skipped assets.
- Never overwrite by a derived display label alone.
- Match stable IDs and hashes when available.
- Offer Keep both, Update, or Skip for conflicts.

### Migration

- Every local database migration is versioned and reversible through a pre-migration backup.
- A failed migration preserves the previous readable store and explains recovery.
- The open-source repository documents breaking export-format changes.

## 11. Privacy boundaries in the IA

- Automatic matching retains only a bounded transient suffix and creates no content record merely because the target is secure or an app was formerly excluded. macOS Secure Input may suppress the events entirely.
- Clipboard changes observed while a clipboard-excluded app is frontmost create no entry. Koru does not claim authoritative clipboard-source attribution when macOS does not expose it.
- Diagnostic state is modeled separately from user content.
- Clearing Clipboard does not delete Saved.
- Resetting learned recall signals does not delete Saved or Clipboard.
- Deleting Saved does not retroactively remove unrelated Clipboard entries, but exact duplicates are made visible during deletion when useful.
- No navigation label implies cloud storage, synchronization, or an account when those capabilities do not exist.

## 12. Information-architecture acceptance criteria

- [ ] The top-level permanent object is always called a saved item.
- [ ] A saved item requires reusable content and one or more exact trigger tags, with no user-authored title or behavior subtype.
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
