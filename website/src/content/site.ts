export const site = {
  name: 'Koru',
  title: 'Koru — Writing memory for macOS',
  description: 'Recall saved writing, reusable templates, and recent clipboard items beside the caret. Local-first and open source for macOS.',
  url: 'https://koru.pages.dev',
  repository: 'https://github.com/builderking/koru',
  releases: 'https://github.com/builderking/koru/releases',
  discussions: 'https://github.com/builderking/koru/discussions',
  license: 'https://github.com/builderking/koru/blob/main/LICENSE',
  contributing: 'https://github.com/builderking/koru/blob/main/CONTRIBUTING.md',
  securityReporting: 'https://github.com/builderking/koru/security/advisories/new',
} as const;

export const releaseStatus = {
  label: 'Pre-release',
  heading: 'Koru is being built in public.',
  body: 'There is no supported app download yet. The interaction model, privacy contract, and engineering plan are public while the native feasibility work begins.',
} as const;
