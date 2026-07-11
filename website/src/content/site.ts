export const site = {
  name: 'Koru',
  title: 'Koru — Writing memory for your Mac',
  description:
    'Koru is a free macOS app that remembers the text you choose to keep — replies, snippets, prompts, templates — and brings it back right where you are typing. Local and private.',
  url: 'https://koru-dc8.pages.dev',
  company: 'BuilderKing',
  companyUrl: 'https://builderking.io',
  supportEmail: 'support@builderking.io',
  securityEmail: 'security@builderking.io',
} as const;

export const download = {
  // Internal page every "Download" call to action points at.
  page: '/download/',
  // TODO: replace with the real signed artifact URL when download functionality ships.
  artifactUrl: '#',
  requirement: 'macOS 13 or later',
  architectures: 'Apple Silicon & Intel',
  price: 'Free',
} as const;
