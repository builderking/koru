export const site = {
  name: 'Koru',
  title: 'Koru — Writing memory for your Mac',
  description:
    'Koru is a free macOS app that saves reusable text with trigger tags and brings it back anywhere you are typing. Local and private.',
  url: 'https://koru-dc8.pages.dev',
  company: 'BuilderKing',
  companyUrl: 'https://builderking.io',
  supportEmail: 'support@builderking.io',
  securityEmail: 'security@builderking.io',
} as const;

export const download = {
  // Internal page every "Download" call to action points at.
  page: '/download/',
  // Refreshed by scripts/package-website-download.sh on every app build.
  artifactUrl: '/downloads/Koru.zip',
  checksumUrl: '/downloads/Koru.zip.sha256',
  requirement: 'macOS 13 or later',
  architectures: 'Apple Silicon & Intel',
  price: 'Free',
} as const;
