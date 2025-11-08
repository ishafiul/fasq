import type { Metadata } from 'next'
import Link from 'next/link'
import { DEFAULT_DESCRIPTION, SITE_URL, defaultImage } from '../lib/seo'

export const metadata: Metadata = {
  title: 'Fasq | Flutter Async State Query',
  description: DEFAULT_DESCRIPTION,
  alternates: {
    canonical: SITE_URL
  },
  openGraph: {
    url: SITE_URL,
    title: 'Fasq | Flutter Async State Query',
    description: DEFAULT_DESCRIPTION,
    images: [defaultImage]
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Fasq | Flutter Async State Query',
    description: DEFAULT_DESCRIPTION,
    images: [defaultImage.url]
  }
}

export default function IndexPage() {
  return (
    <div style={{ textAlign: 'center', padding: '50px 20px', backgroundColor: '#0a0a0a', minHeight: '100vh' }}>
      <h1
        style={{
          fontSize: 64,
          margin: '0 0 20px 0',
          fontWeight: 'bold',
          background: 'linear-gradient(45deg, #667eea 0%, #764ba2 100%)',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
        }}
      >
        Fasq
      </h1>
      <p style={{ fontSize: 24, marginBottom: 40, color: '#a0a0a0' }}>
        Flutter Async State Query - Powerful data fetching and caching for Flutter
      </p>
      
      <div style={{ display: 'flex', gap: '20px', justifyContent: 'center', flexWrap: 'wrap', marginBottom: 60 }}>
        <Link 
          href="/docs" 
          style={{
            padding: '12px 24px',
            backgroundColor: '#667eea',
            color: 'white',
            textDecoration: 'none',
            borderRadius: '8px',
            fontWeight: 'bold',
            transition: 'background-color 0.3s'
          }}
        >
          📚 Documentation
        </Link>
        <Link 
          href="/docs/quick-start" 
          style={{
            padding: '12px 24px',
            backgroundColor: '#764ba2',
            color: 'white',
            textDecoration: 'none',
            borderRadius: '8px',
            fontWeight: 'bold',
            transition: 'background-color 0.3s'
          }}
        >
          🚀 Quick Start
        </Link>
        <Link 
          href="/docs/examples" 
          style={{
            padding: '12px 24px',
            backgroundColor: '#f093fb',
            color: 'white',
            textDecoration: 'none',
            borderRadius: '8px',
            fontWeight: 'bold',
            transition: 'background-color 0.3s'
          }}
        >
          💡 Examples
        </Link>
      </div>
      
      <div style={{ maxWidth: 1000, margin: '0 auto' }}>
        <h2 style={{ fontSize: 32, marginBottom: 40, color: '#ffffff' }}>What is Fasq?</h2>
        <div style={{ fontSize: 18, lineHeight: 1.6, marginBottom: 60, textAlign: 'left', maxWidth: 800, margin: '0 auto 60px auto', color: '#d0d0d0' }}>
          <p>
            Fasq is a comprehensive Flutter package that brings powerful data fetching, caching, and state management capabilities to your Flutter applications. 
            Inspired by React Query (TanStack Query), Fasq provides intelligent caching, background refetching, and seamless integration with popular Flutter state management solutions.
          </p>
          <p>
            Whether you&apos;re building a simple app with REST APIs or a complex application with real-time data, Fasq handles the complexity of data synchronization, 
            caching, and error handling so you can focus on building great user experiences.
          </p>
        </div>
        
        <h2 style={{ fontSize: 32, marginBottom: 40, color: '#ffffff' }}>Choose Your Integration</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '20px', textAlign: 'left', marginBottom: 60 }}>
          <div style={{ padding: '20px', border: '1px solid #333', borderRadius: '8px', backgroundColor: '#1a1a1a' }}>
            <h3 style={{ color: '#ffffff' }}>🎣 Hooks Adapter</h3>
            <p style={{ color: '#d0d0d0' }}>Use Fasq with flutter_hooks for declarative data fetching. Perfect for functional components and modern Flutter development.</p>
            <div style={{ marginTop: 15 }}>
              <code style={{ backgroundColor: '#2a2a2a', color: '#667eea', padding: '4px 8px', borderRadius: '4px', fontSize: '14px' }}>
                useQuery, useMutation, useQueryClient
              </code>
            </div>
            <Link href="/docs/hooks" style={{ color: '#667eea', textDecoration: 'none', fontWeight: 'bold' }}>Learn more →</Link>
          </div>
          <div style={{ padding: '20px', border: '1px solid #333', borderRadius: '8px', backgroundColor: '#1a1a1a' }}>
            <h3 style={{ color: '#ffffff' }}>🧊 Bloc Adapter</h3>
            <p style={{ color: '#d0d0d0' }}>Integrate Fasq with flutter_bloc for structured state management. Ideal for complex applications with clear separation of concerns.</p>
            <div style={{ marginTop: 15 }}>
              <code style={{ backgroundColor: '#2a2a2a', color: '#667eea', padding: '4px 8px', borderRadius: '4px', fontSize: '14px' }}>
                QueryCubit, MutationCubit
              </code>
            </div>
            <Link href="/docs/bloc" style={{ color: '#667eea', textDecoration: 'none', fontWeight: 'bold' }}>Learn more →</Link>
          </div>
          <div style={{ padding: '20px', border: '1px solid #333', borderRadius: '8px', backgroundColor: '#1a1a1a' }}>
            <h3 style={{ color: '#ffffff' }}>🔌 Riverpod Adapter</h3>
            <p style={{ color: '#d0d0d0' }}>Leverage Fasq with flutter_riverpod for compile-safe providers and dependency injection. Great for scalable applications.</p>
            <div style={{ marginTop: 15 }}>
              <code style={{ backgroundColor: '#2a2a2a', color: '#667eea', padding: '4px 8px', borderRadius: '4px', fontSize: '14px' }}>
                queryProvider, mutationProvider
              </code>
            </div>
            <Link href="/docs/riverpod" style={{ color: '#667eea', textDecoration: 'none', fontWeight: 'bold' }}>Learn more →</Link>
          </div>
          <div style={{ padding: '20px', border: '1px solid #333', borderRadius: '8px', backgroundColor: '#1a1a1a' }}>
            <h3 style={{ color: '#ffffff' }}>⚡ Core Package</h3>
            <p style={{ color: '#d0d0d0' }}>Use Fasq&apos;s core widgets directly for maximum flexibility. Perfect for custom implementations and learning the fundamentals.</p>
            <div style={{ marginTop: 15 }}>
              <code style={{ backgroundColor: '#2a2a2a', color: '#667eea', padding: '4px 8px', borderRadius: '4px', fontSize: '14px' }}>
                QueryBuilder, MutationBuilder
              </code>
            </div>
            <Link href="/docs/core" style={{ color: '#667eea', textDecoration: 'none', fontWeight: 'bold' }}>Learn more →</Link>
          </div>
        </div>
        
        <h2 style={{ fontSize: 32, marginBottom: 40, color: '#ffffff' }}>Key Features</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '20px', textAlign: 'left', marginBottom: 60 }}>
          <div style={{ padding: '20px', border: '1px solid #333', borderRadius: '8px', backgroundColor: '#1a1a1a' }}>
            <h3 style={{ color: '#667eea' }}>⚡ Intelligent Caching</h3>
            <p style={{ color: '#d0d0d0' }}>Automatic caching with configurable staleness detection. Data is cached intelligently and served instantly when available.</p>
          </div>
          <div style={{ padding: '20px', border: '1px solid #333', borderRadius: '8px', backgroundColor: '#1a1a1a' }}>
            <h3 style={{ color: '#667eea' }}>🔄 Request Deduplication</h3>
            <p style={{ color: '#d0d0d0' }}>Multiple requests for the same data automatically deduplicated. Only one network call per unique query.</p>
          </div>
          <div style={{ padding: '20px', border: '1px solid #333', borderRadius: '8px', backgroundColor: '#1a1a1a' }}>
            <h3 style={{ color: '#667eea' }}>🎯 Type Safety</h3>
            <p style={{ color: '#d0d0d0' }}>Full generic type support with compile-time safety. Catch errors at development time, not runtime.</p>
          </div>
          <div style={{ padding: '20px', border: '1px solid #333', borderRadius: '8px', backgroundColor: '#1a1a1a' }}>
            <h3 style={{ color: '#667eea' }}>🚀 Background Refetching</h3>
            <p style={{ color: '#d0d0d0' }}>Stale data served instantly while fresh data loads in the background. Users never wait for data they already have.</p>
          </div>
          <div style={{ padding: '20px', border: '1px solid #333', borderRadius: '8px', backgroundColor: '#1a1a1a' }}>
            <h3 style={{ color: '#667eea' }}>🔄 Optimistic Updates</h3>
            <p style={{ color: '#d0d0d0' }}>Update UI immediately and rollback on error. Provide instant feedback for better user experience.</p>
          </div>
          <div style={{ padding: '20px', border: '1px solid #333', borderRadius: '8px', backgroundColor: '#1a1a1a' }}>
            <h3 style={{ color: '#667eea' }}>🛠️ Error Handling</h3>
            <p style={{ color: '#d0d0d0' }}>Comprehensive error handling with retry mechanisms, fallback strategies, and user-friendly error messages.</p>
          </div>
        </div>

        <h2 style={{ fontSize: 32, marginBottom: 40, color: '#ffffff' }}>Quick Example</h2>
        <div style={{ backgroundColor: '#1a1a1a', padding: '20px', borderRadius: '8px', textAlign: 'left', marginBottom: 60, border: '1px solid #333' }}>
          <pre style={{ margin: 0, fontSize: '14px', lineHeight: 1.5, overflow: 'auto', color: '#d0d0d0' }}>
{`// Using fasq_hooks
class UserProfile extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final userQuery = useQuery<User>(
      queryKey: 'user-profile',
      queryFn: () => api.getUserProfile(),
    );

    return userQuery.when(
      loading: () => CircularProgressIndicator(),
      error: (error) => Text('Error: \$error'),
      data: (user) => Column(
        children: [
          Text('Name: \${user.name}'),
          Text('Email: \${user.email}'),
        ],
      ),
    );
  }
}`}
          </pre>
        </div>

        <h2 style={{ fontSize: 32, marginBottom: 40, color: '#ffffff' }}>Is FASQ Right for You?</h2>
        <div style={{ backgroundColor: '#1a1a1a', padding: '30px', borderRadius: '12px', marginBottom: 60, border: '1px solid #333' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '30px', textAlign: 'left' }}>
            <div>
              <h3 style={{ color: '#4ade80', fontSize: '20px', marginBottom: '15px' }}>✅ Choose FASQ if you have:</h3>
              <ul style={{ color: '#d0d0d0', lineHeight: '1.8', paddingLeft: '20px' }}>
                <li>Multiple API endpoints to manage</li>
                <li>Complex caching requirements</li>
                <li>Need for request deduplication</li>
                <li>Background data synchronization</li>
                <li>Team standardization needs</li>
                <li>Performance-critical applications</li>
              </ul>
            </div>
            <div>
              <h3 style={{ color: '#f87171', fontSize: '20px', marginBottom: '15px' }}>❌ Consider alternatives if you:</h3>
              <ul style={{ color: '#d0d0d0', lineHeight: '1.8', paddingLeft: '20px' }}>
                <li>Have simple, single API calls</li>
                <li>Need micro-level performance control</li>
                <li>Want minimal bundle size</li>
                <li>Are new to Flutter development</li>
                <li>Have unique state management needs</li>
                <li>Prefer complete code ownership</li>
              </ul>
            </div>
          </div>
          <div style={{ marginTop: '25px', padding: '20px', backgroundColor: '#2a2a2a', borderRadius: '8px', border: '1px solid #444' }}>
            <p style={{ color: '#a0a0a0', fontSize: '16px', margin: '0', textAlign: 'center' }}>
              <strong style={{ color: '#ffffff' }}>Bottom Line:</strong> FASQ gives you <strong style={{ color: '#4ade80' }}>strategic control</strong> over async state management with <strong style={{ color: '#4ade80' }}>rapid development</strong>, 
              but you trade <strong style={{ color: '#f87171' }}>implementation control</strong> for <strong style={{ color: '#4ade80' }}>proven patterns</strong>.
            </p>
          </div>
        </div>

        <h2 style={{ fontSize: 32, marginBottom: 40, color: '#ffffff' }}>Get Started</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '20px', textAlign: 'left' }}>
          <div style={{ padding: '20px', border: '1px solid #333', borderRadius: '8px', backgroundColor: '#1a1a1a' }}>
            <h3 style={{ color: '#ffffff' }}>📖 Learn the Basics</h3>
            <p style={{ color: '#d0d0d0' }}>Start with our comprehensive documentation covering core concepts, installation, and basic usage patterns.</p>
            <Link href="/docs/core-concepts" style={{ color: '#667eea', textDecoration: 'none', fontWeight: 'bold' }}>Read Documentation →</Link>
          </div>
          <div style={{ padding: '20px', border: '1px solid #333', borderRadius: '8px', backgroundColor: '#1a1a1a' }}>
            <h3 style={{ color: '#ffffff' }}>🚀 Try Examples</h3>
            <p style={{ color: '#d0d0d0' }}>Explore real-world examples including REST APIs, GraphQL, authentication, and database integration.</p>
            <Link href="/docs/examples" style={{ color: '#667eea', textDecoration: 'none', fontWeight: 'bold' }}>View Examples →</Link>
          </div>
          <div style={{ padding: '20px', border: '1px solid #333', borderRadius: '8px', backgroundColor: '#1a1a1a' }}>
            <h3 style={{ color: '#ffffff' }}>🔧 Choose Your Adapter</h3>
            <p style={{ color: '#d0d0d0' }}>Pick the integration that fits your project: Hooks, Bloc, Riverpod, or use the core package directly.</p>
            <Link href="/docs/installation" style={{ color: '#667eea', textDecoration: 'none', fontWeight: 'bold' }}>Install Now →</Link>
          </div>
        </div>
      </div>
    </div>
  )
}