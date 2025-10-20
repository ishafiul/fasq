/* eslint-env node */
import { Footer, Layout, Navbar } from 'nextra-theme-docs'
import { Head } from 'nextra/components'
import { getPageMap } from 'nextra/page-map'
import 'nextra-theme-docs/style.css'

export const metadata = {
  metadataBase: new URL('https://fasq.dev'),
  title: {
    template: '%s - Fasq'
  },
  description: 'Fasq: Powerful async state management for Flutter. Handles API calls, database queries, and any async operation with intelligent caching and automatic refetching.',
  applicationName: 'Fasq',
  generator: 'Next.js',
  appleWebApp: {
    title: 'Fasq'
  },
  other: {
    'msapplication-TileImage': '/ms-icon-144x144.png',
    'msapplication-TileColor': '#667eea'
  },
  twitter: {
    site: 'https://fasq.dev',
    card: 'summary_large_image'
  },
  openGraph: {
    type: 'website',
    siteName: 'Fasq',
    title: 'Fasq - Powerful Async State Management for Flutter',
    description: 'Handles API calls, database queries, and any async operation with intelligent caching, automatic refetching, and error recovery.',
  }
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
    />
  )
  const pageMap = await getPageMap()
  return (
    <html lang="en" dir="ltr" suppressHydrationWarning>
      <Head faviconGlyph="✦" />
      <body>
        <Layout
          navbar={navbar}
          footer={<Footer>MIT {new Date().getFullYear()} © Fasq.</Footer>}
          editLink="Edit this page on GitHub"
          docsRepositoryBase="https://github.com/yourusername/fasq/tree/main/fasq-docs/src/content"
          sidebar={{ defaultMenuCollapseLevel: 1 }}
          pageMap={pageMap}
  
        >
          {children}
        </Layout>
      </body>
    </html>
  )
}