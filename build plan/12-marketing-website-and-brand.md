# Koru marketing website and brand

Status: build-ready product and content specification
Site form: one minimal, state-of-the-art landing site
Repository location: website/
Framework: Astro static output

## Website objective

The site has one job: help a Mac user understand Koru in ten seconds and decide whether to inspect or try it.

The visitor should leave the first screen knowing:

1. Koru remembers useful writing;
2. recall happens beside the caret;
3. permanent saved items and temporary Recent clipboard entries live in one recall surface;
4. it works locally and is open source;
5. there is an honest way to download or inspect it.

The site should feel as focused as the product. It is not a documentation portal, blog, account dashboard, pricing funnel, or generic AI landing page.

## Brand decision and required diligence

**Koru** is the working product and repository name. It is not yet approved for an irreversible logo system or trademark claim.

Koru is a Māori word and a culturally significant visual form. The Intellectual Property Office of New Zealand explains that a koru depicts an unfolding fern frond and that Māori words and imagery deserve special consideration. Its trademark guidance encourages specialist advice or engagement with Māori before adopting marks derived from Māori culture. It also notes that even a spiral intended to reference another culture may be interpreted as a koru.

References:

- IPONZ, [Concepts to understand](https://www.iponz.govt.nz/get-ip/maori-ip/concepts-to-understand/)
- IPONZ, [Māori advisory committee and Māori trade marks](https://www.iponz.govt.nz/get-ip/trade-marks/practice-guidelines/current/maori-advisory-committee-and-maori-trade-marks/)
- Te Ara, [The koru](https://teara.govt.nz/en/photograph/2422/the-koru)

Before public brand launch:

- search relevant software and productivity trademark classes in launch markets;
- obtain professional trademark advice;
- engage an appropriate Māori language or cultural advisor about the name, narrative, and imagery;
- avoid a literal koru spiral, faux Māori pattern, or appropriated visual language unless designed through informed collaboration;
- document pronunciation and meaning accurately if the website tells a name story;
- be willing to rename before user recognition and distribution make the cost high.

Until this gate is passed, use a simple wordmark and a neutral product glyph based on writing recall, not Māori art.

## Brand idea

The product idea is **returning to useful thought**.

The visual and verbal system should evoke:

- calm recall rather than frantic search;
- continuity rather than automation spectacle;
- a private tool rather than a cloud service;
- a small native utility rather than a large workspace;
- memory that remains under the user's control.

Do not claim that this interpretation is the cultural meaning of the word Koru. It is the product's own behavioral idea.

## Voice

Koru speaks in short, concrete sentences.

### Voice traits

- **Plain:** “Find the words you saved,” not “unlock your knowledge substrate.”
- **Specific:** “Saved writing, reusable templates, and recent clipboard items,” not “everything you need.”
- **Calm:** no artificial urgency, fear, or countdowns.
- **Honest:** state supported applications and limitations.
- **Respectful:** never treat private writing as raw material for vague AI claims.
- **Technical when useful:** local storage, source code, permissions, and retention should be explained precisely.

### Words to prefer

- remember
- recall
- saved writing
- reusable
- recent
- beside the caret
- on your Mac
- inspect
- save permanently
- pause
- exclude

### Words to avoid

- revolutionary
- second brain
- AI-powered, unless a real shipped feature requires the term
- ultimate
- infinite clipboard
- works everywhere
- never lose anything
- magical
- productivity superpower
- prompt manager as the primary category

## Core copy

### Metadata

**Page title**

Koru — Writing memory for macOS

**Meta description**

Recall saved writing, reusable templates, and recent clipboard items beside the caret. Local-first and open source for macOS.

### Hero

**Eyebrow**

Writing memory for macOS

**Headline**

Remember what you meant, even from a fragment.

**Supporting copy**

Koru brings saved writing, reusable templates, and recent clipboard items to the caret, locally on your Mac.

**Primary action**

Download for macOS

**Secondary action**

View source on GitHub

Before a tested binary exists, the primary action becomes:

Join the first public test

It should link to a GitHub Discussion or release-watch route, not an email collection form added only for appearance.

**Trust line**

Free and open source. No account required for the core app.

Do not show “Download” until a signed and notarized artifact exists. The release endpoint should remain the source of truth rather than a manually duplicated website file.

## Single-page structure

### 1. Compact navigation

Left:

- Koru wordmark

Right:

- How it works
- Privacy
- GitHub
- Download

On small screens, keep GitHub and Download visible and collapse only the anchor links. Do not add a full-screen menu for four destinations.

The navigation is translucent only when contrast remains readable. It should not imitate a browser toolbar or stack multiple glass layers.

### 2. Hero with real product loop

The hero contains copy on the left and a native-looking product demonstration on the right or below on narrow screens.

The demo should show one continuous story:

1. the caret is in an ordinary text field;
2. the user invokes Koru and types “push”;
3. a Saved result titled “Push to GitHub safely” is selected;
4. the result is inserted;
5. a second state shows Recent material and a Save action that creates a separate saved item;
6. a final state shows Save Selection.

Use a short, muted, controllable video or a lightweight scripted illustration built from product captures. Provide a static poster and descriptive alternative text. Respect reduced-motion preferences and never autoplay with sound.

Do not fabricate interactions the first beta cannot perform. Replace the demo as the product changes.

### 3. One surface, two storage layers

Headline:

One place for what lasts, what repeats, and what was just copied.

Two compact cards:

**Saved items**

Prompts, passages, commands, replies, and references you choose to keep. Each saved item can behave as Saved text, a Quick replacement, or a Template.

**Recent clipboard**

Clipboard material for now. Use it or search it before it expires, and explicitly save a separate permanent item when it is worth keeping.

The cards share one visual frame to reinforce unified recall. Within the Saved card, three small behavior labels explain Saved text, Quick replacement, and Template without implying separate databases. Recent remains visibly temporary.

### 4. Differentiator sequence

Use four short sections with a screenshot or restrained interaction for each.

**Remember a fragment**

Search by the words you recall, not the exact title or abbreviation.

**Begin with a fragment**

At position zero in a fresh input, type a matching fragment and Koru appears. It never opens merely because the field is empty; the global hotkey opens it immediately when you want to browse.

**Save before it disappears**

Select what you just wrote and save it without opening a separate library.

**Keep memory close**

Core capture, storage, and search stay on your Mac, with visible exclusions and retention controls.

Avoid turning this section into a grid of twelve generic features.

### 5. How it works

A three-step horizontal sequence:

1. **Invoke** — Use the Koru shortcut in the field where you are writing.
2. **Recall** — Type any remembered fragment at the start of a fresh input, or use the hotkey to browse immediately.
3. **Insert or keep** — Insert, copy, save a selection, or save a Recent item permanently.

Include keyboard navigation in the visual. The site should communicate that the product remains fully usable without the pointer.

### 6. Privacy and open-source proof

Headline:

Your writing memory should be understandable.

Copy:

Koru's core works without an account. See what is captured, exclude applications, pause history, choose retention, delete everything, and inspect the code that does it.

Proof links:

- Read the privacy model
- Inspect the source
- Report a security issue

Use a factual checklist tied to shipped behavior:

- local storage location;
- default clipboard retention;
- excluded secure fields and applications;
- network requests;
- analytics or crash-reporting state;
- deletion and export behavior.

Do not publish a broad “100% private” badge. Privacy is a behavior contract, not a decorative claim.

### 7. Compatibility

Show the tested macOS range and a short verified application matrix. Separate:

- works as tested;
- works with limitations;
- not supported;
- under evaluation.

Link to the full compatibility document in the repository. “Native macOS” must not become “works in every Mac text field.”

### 8. Open-source invitation

Headline:

Built in the open.

Copy:

Koru is free and open source under Apache-2.0. Follow the roadmap, inspect privacy-sensitive code, report application compatibility, or help build it.

Actions:

- View builderking/koru
- Read the contribution guide
- Join Discussions

Show repository statistics only if they load without third-party tracking and add real trust. Empty star counters are not launch content.

### 9. Focused FAQ

Include only questions that remove adoption anxiety:

- What does Koru capture?
- Does Koru upload my writing?
- How is Koru different from macOS text replacements and clipboard history?
- Does it replace Raycast, Alfred, or my current text expander?
- Which Mac applications work?
- Can I disable Koru in password managers or specific apps?
- Where is my data stored, and can I export or delete it?
- Why does macOS request Accessibility or Input Monitoring permission?
- Is Koru free?

Answers must be generated from the shipped privacy and compatibility contracts, not from this design document.

### 10. Final action and footer

Final headline:

Stop rebuilding words you already got right.

Actions:

- Download for macOS
- View source

Footer:

- GitHub
- Documentation
- Privacy
- Security
- License
- Releases
- BuilderKing
- copyright statement

No newsletter box, social wall, multi-column sitemap, pricing, or blog archive at launch.

## Visual direction

### Palette

Use a restrained neutral system with one calm accent:

| Token | Direction | Use |
| --- | --- | --- |
| Canvas | warm near-white | page background |
| Ink | near-black with a warm cast | primary text |
| Muted ink | middle neutral | supporting copy |
| Panel | soft opaque neutral | cards and product framing |
| Accent | subdued fern or mineral green, pending cultural review | actions, focus, active row |
| Hairline | low-contrast neutral | separators |
| Dark canvas | deep neutral, not pure black | optional system dark mode |

Pass WCAG contrast rather than choosing exact colors by mood alone. Do not use a green spiral or claim a fern-derived brand system before cultural review.

### Typography

Use a system font stack led by the macOS system font:

    -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif

Do not distribute Apple fonts with the website. Use weight, spacing, and size rather than multiple display faces. A monospace system stack may appear only in small trigger or keyboard examples.

### Layout

- content width approximately 1120 to 1200 CSS pixels;
- generous vertical rhythm;
- headline line length no more than roughly 12 words per line;
- body copy around 60 to 72 characters per line;
- product UI shown at a believable size;
- one primary visual idea per section;
- rounded geometry that echoes macOS without copying private Apple assets.

### Material and motion

The product popover may use native Liquid Glass when the implementation supports it. The website should render an accessible interpretation, not reproduce proprietary system effects with excessive blur.

- one translucent shell at a time;
- opaque-enough text surfaces;
- no glass-on-glass card stacks;
- short opacity and transform transitions;
- no scroll hijacking;
- no cursor follower;
- no animated gradient background;
- no ambient particle field;
- reduced-motion mode removes non-essential movement.

Apple's current design references:

- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers/)
- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

## Responsive behavior

The page must remain a first-class product page on small laptops and phones, not merely shrink.

- stack hero copy before the demonstration below the desktop breakpoint;
- keep primary and secondary actions full-width only on narrow screens;
- preserve product-loop legibility with a cropped, purpose-made mobile poster;
- convert horizontal step or card arrangements to a single reading column;
- avoid carousels;
- maintain 44 CSS pixel minimum interactive targets;
- test 200 percent zoom and long localized strings;
- allow the navigation and CTA text to wrap without clipping.

The macOS product itself is desktop-only, but prospective users will discover it on mobile. The site should let them understand the product and open the GitHub repository without pretending they can install it on iPhone.

## Accessibility requirements

- semantic landmarks and one H1;
- logical heading structure;
- fully keyboard-operable navigation and demo controls;
- visible focus rings with sufficient contrast;
- captions or an equivalent text transcript for product video;
- meaningful alternative text for screenshots and an empty alt attribute for decoration;
- no information conveyed only by color;
- reduced-motion support;
- readable at 200 percent zoom;
- current-page and expanded-state semantics;
- no focus traps;
- form-free launch page unless a real signup need is approved;
- manual VoiceOver pass on macOS and iOS Safari;
- automated accessibility checks in CI.

## Performance budget

The site should feel immediate and reflect Koru's product values.

- default to Astro's static HTML and CSS;
- ship no client-side JavaScript unless it produces a specific useful interaction;
- use responsive AVIF or WebP images with explicit dimensions and a PNG fallback where needed;
- use a poster and deferred loading for video below the first meaningful content;
- avoid third-party tag managers, chat widgets, font loaders, and social embeds;
- keep initial compressed page weight low enough for a fast mobile connection;
- target strong Core Web Vitals and a Lighthouse performance score of at least 95 in a controlled production test;
- ensure the hero's largest content element is loaded predictably, not injected after JavaScript.

Performance numbers are release gates to measure, not claims to print on the site.

## Search and social metadata

Include:

- canonical URL once the public domain is decided;
- unique title and description;
- Open Graph and social preview image;
- favicon and mask icon;
- web app manifest only if it has a real install role;
- robots.txt;
- sitemap;
- SoftwareApplication structured data using only factual release details;
- source and download URLs;
- privacy, security, and license links.

Preview deployments must remain non-indexed. Cloudflare Pages adds an X-Robots-Tag: noindex header to preview deployments by default; verify it rather than relying on memory.

Do not publish review ratings, pricing, operating-system compatibility, or release version in structured data unless the values are generated from the current release source.

## Analytics decision

Launch without third-party behavioral analytics.

Server-side aggregate request analytics may be evaluated only after the team documents:

- the exact questions it answers;
- fields collected;
- retention;
- processor and region;
- consent and disclosure requirements;
- how preview and maintainer traffic are excluded.

Download clicks can initially be inferred from GitHub release data. If site analytics are added, the privacy page and repository must reflect them before collection starts.

No session replay, heatmap, fingerprinting, advertising pixel, or user-level writing-demo capture belongs on this site.

## Astro implementation shape

Recommended structure:

    website/
      astro.config.mjs
      package.json
      package-lock.json
      .node-version
      public/
        _headers
        favicon.svg
        robots.txt
        media/
      src/
        components/
          Navigation.astro
          Hero.astro
          ProductLoop.astro
          MemoryTypes.astro
          FeatureSection.astro
          HowItWorks.astro
          PrivacyProof.astro
          Compatibility.astro
          OpenSource.astro
          Faq.astro
          Footer.astro
        content/
          site.ts
        layouts/
          BaseLayout.astro
        pages/
          index.astro
          privacy.astro
          security.astro
        styles/
          tokens.css
          global.css

The public experience is one landing site. Small privacy and security pages exist because durable, linkable policy content should not be hidden in an accordion. They use the same minimal shell and are not marketed as separate site sections.

Use static content and Astro components. Do not add React, Vue, a content-management system, Cloudflare Functions, or an Astro Cloudflare adapter unless a later requirement makes client or server runtime behavior necessary.

## Content and asset checklist

Before production publishing:

- current signed-release URL or honest pre-release CTA;
- real application icon;
- culturally reviewed wordmark and brand decision;
- real product screenshot at standard and Retina resolution;
- reduced-motion-safe product loop and static poster;
- current supported macOS range;
- verified application compatibility table;
- accurate permission screenshots from the current macOS release;
- final Apache-2.0 license link;
- public privacy model;
- public SECURITY.md route;
- GitHub Discussions and contribution links;
- social preview image;
- favicon set;
- alt text and video transcript;
- source attribution for every asset.

## Acceptance criteria

The marketing site is ready when:

- a new visitor can explain that saved items are permanent, may behave as Saved text, Quick replacement, or Template, and that Recent clipboard entries are temporary;
- the hero distinguishes Koru without claiming to invent prompts, snippets, or clipboard history;
- every visible claim maps to shipped and tested behavior;
- download links resolve to signed releases;
- the page works without client-side JavaScript, except an optional enhanced demo;
- keyboard, VoiceOver, contrast, zoom, and reduced-motion checks pass;
- local production build outputs static files to website/dist;
- no secret, account identifier, unpublished customer content, or analytics token is in the output;
- preview deployments are non-indexed;
- privacy, security, source, license, and release links work;
- the Koru name and visual system have passed trademark and cultural review.

## Explicit non-goals

- a separate prompt marketplace;
- template browsing or public user profiles;
- pricing and subscription pages;
- a blog or changelog duplicated from GitHub;
- interactive cloud accounts;
- a support chatbot;
- a multi-page SEO content farm;
- claims that the app replaces every existing clipboard or launcher workflow;
- visual mimicry of Apple marketing pages.
