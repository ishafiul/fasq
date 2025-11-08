import type { MetadataRoute } from 'next'
import { generateStaticParamsFor } from 'nextra/pages'
import { SITE_URL } from '../lib/seo'

type SitemapEntry = {
  url: string
  lastModified: string
}

const normalizeRoute = (segments: string[]) =>
  segments.length === 0 ? '/docs' : `/docs/${segments.join('/')}`

const collectDocRoutes = async () => {
  const toParams = generateStaticParamsFor('mdxPath')
  const params = await toParams()
  const timestamp = new Date().toISOString()
  return params.map((param) => {
    const segments = Array.isArray(param.mdxPath) ? (param.mdxPath as string[]) : []
    const route = normalizeRoute(segments)
    return {
      url: `${SITE_URL}${route}`,
      lastModified: timestamp
    }
  })
}

const dedupeRoutes = (routes: SitemapEntry[]) => {
  const map = new Map<string, SitemapEntry>()
  for (const entry of routes) {
    const existing = map.get(entry.url)
    if (!existing || new Date(entry.lastModified) > new Date(existing.lastModified)) {
      map.set(entry.url, entry)
    }
  }
  return Array.from(map.values())
}

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const docRoutes = await collectDocRoutes()
  const timestamp = new Date().toISOString()
  const entries: SitemapEntry[] = [
    {
      url: SITE_URL,
      lastModified: timestamp
    },
    {
      url: `${SITE_URL}/docs`,
      lastModified: timestamp
    },
    ...docRoutes
  ]

  const deduped = dedupeRoutes(entries)
  return deduped.map((entry) => ({
    url: entry.url,
    lastModified: entry.lastModified
  }))
}


