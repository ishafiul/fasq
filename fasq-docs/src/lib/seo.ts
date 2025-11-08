import type { Metadata } from 'next'

export const SITE_URL = 'https://fasq.shafi.dev'
export const DEFAULT_DESCRIPTION =
  'Fasq delivers caching-first async state management for Flutter with intelligent refetching, resilient error handling, and adapters for Bloc, Riverpod, and Hooks.'

const DEFAULT_IMAGE = {
  url: `${SITE_URL}/opengraph-image.png`,
  width: 1200,
  height: 630,
  alt: 'Fasq async state management'
}

const DEFAULT_KEYWORDS = [
  'fasq',
  'flutter async state query',
  'flutter query caching',
  'flutter bloc data fetching',
  'flutter riverpod query',
  'flutter hooks query',
  'flutter state management',
  'async caching'
]

type DocMetadataInput = {
  mdxMetadata?: Partial<Metadata>
  mdxPath?: string[]
}

type TwitterWithCard = Extract<NonNullable<Metadata['twitter']>, { card: string }>

const hasTwitterCard = (twitter: Metadata['twitter']): twitter is TwitterWithCard =>
  Boolean(twitter && typeof twitter === 'object' && 'card' in twitter)

const toStartCase = (segments: string[]) =>
  segments
    .map((segment) =>
      segment
        .split('-')
        .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ')
    )
    .join(' · ')

const resolveDocRoute = (segments: string[] = []) =>
  segments.length === 0 ? '/docs' : `/docs/${segments.join('/')}`

export const buildDocMetadata = ({
  mdxMetadata,
  mdxPath
}: DocMetadataInput): Metadata => {
  const route = resolveDocRoute(mdxPath ?? [])
  const titleFromPath = mdxPath && mdxPath.length > 0 ? toStartCase(mdxPath) : 'Documentation'
  const baseTitle = mdxMetadata?.title ?? `Fasq ${titleFromPath}`
  const description = mdxMetadata?.description ?? DEFAULT_DESCRIPTION
  const mdxTwitter = mdxMetadata?.twitter
  const twitterCard = hasTwitterCard(mdxTwitter) ? mdxTwitter.card : 'summary_large_image'
  const canonical = `${SITE_URL}${route}`

  const merged: Metadata = {
    ...mdxMetadata,
    title: mdxMetadata?.title ?? baseTitle,
    description,
    keywords: mdxMetadata?.keywords ?? DEFAULT_KEYWORDS,
    alternates: {
      ...mdxMetadata?.alternates,
      canonical
    },
    openGraph: {
      ...mdxMetadata?.openGraph,
      title: mdxMetadata?.openGraph?.title ?? baseTitle,
      description: mdxMetadata?.openGraph?.description ?? description,
      url: mdxMetadata?.openGraph?.url ?? canonical,
      type: 'article',
      images: mdxMetadata?.openGraph?.images ?? [DEFAULT_IMAGE]
    },
    twitter: {
      ...mdxTwitter,
      card: twitterCard,
      title: mdxTwitter?.title ?? baseTitle,
      description: mdxTwitter?.description ?? description,
      images: mdxTwitter?.images ?? [DEFAULT_IMAGE.url]
    }
  }

  return merged
}

export const organizationJsonLd = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'Fasq',
  applicationCategory: 'DeveloperApplication',
  operatingSystem: 'Cross-platform',
  description: DEFAULT_DESCRIPTION,
  url: SITE_URL,
  offers: {
    '@type': 'Offer',
    price: '0',
    priceCurrency: 'USD'
  },
  publisher: {
    '@type': 'Organization',
    name: 'Fasq'
  }
}

export const defaultImage = DEFAULT_IMAGE
export const defaultKeywords = DEFAULT_KEYWORDS


