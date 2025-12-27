/* eslint-env node */
import type { Metadata } from 'next'
import Script from 'next/script'
import { Footer, Layout, Navbar } from 'nextra-theme-docs'
import { Head } from 'nextra/components'
import { getPageMap } from 'nextra/page-map'
import 'nextra-theme-docs/style.css'
import { DEFAULT_DESCRIPTION, SITE_URL, defaultImage, defaultKeywords, organizationJsonLd } from '../lib/seo'

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  verification: {
    google: 'h7MgEHQ_gxAuhF2zy-ZYpfdaZ3erRDe-4hVLesv9-s8',
  },
  title: {
    default: 'Fasq Documentation',
    template: '%s · Fasq'
  },
  description: DEFAULT_DESCRIPTION,
  keywords: defaultKeywords,
  applicationName: 'Fasq',
  generator: 'Next.js',
  authors: [{ name: 'Fasq', url: SITE_URL }],
  creator: 'Fasq',
  publisher: 'Fasq',
  category: 'technology',
  alternates: {
    canonical: SITE_URL
  },
  openGraph: {
    type: 'website',
    siteName: 'Fasq',
    url: SITE_URL,
    title: 'Fasq Documentation',
    description: DEFAULT_DESCRIPTION,
    images: [defaultImage]
  },
  twitter: {
    site: '@fasq_dev',
    creator: '@fasq_dev',
    card: 'summary_large_image',
    title: 'Fasq Documentation',
    description: DEFAULT_DESCRIPTION,
    images: [defaultImage.url]
  },
  icons: {
    icon: '/favicon.ico'
  },
  themeColor: '#0a0a0a'
}

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const navbar = (
    <Navbar
      logo={
        <div>
          <b>Fasq</b>{' '}
          <span style={{ opacity: '60%' }}>Async State Management</span>
        </div>
      }
      projectLink="https://github.com/ishafiul/fasq"
    >
      <a
        href="https://pub.dev/packages/fasq"
        target="_blank"
        rel="noreferrer"
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: '6px',
          paddingLeft: '12px',
          fontWeight: 600
        }}
      >
        <img src="/pub-dev-logo.svg" alt="Pub.dev" style={{ height: '18px', width: 'auto' }} />
      </a>
    </Navbar>
  )
  const pageMap = await getPageMap()
  return (
    <html lang="en" dir="ltr" suppressHydrationWarning>
      <Head faviconGlyph="F" />
      <body>
        <Script id="fasq-organization" type="application/ld+json" strategy="beforeInteractive">
          {JSON.stringify(organizationJsonLd)}
        </Script>
        <Layout
          navbar={navbar}
          footer={<Footer>MIT {new Date().getFullYear()} © Fasq.</Footer>}
          editLink="Edit this page on GitHub"
          docsRepositoryBase="https://github.com/ishafiul/fasq/tree/main/fasq-docs/src/content"
          sidebar={{ defaultMenuCollapseLevel: 1 }}
          pageMap={pageMap}

        >
          {children}
        </Layout>
      </body>
    </html>
  )
}