import type { NextConfig } from "next";

const withNextra = nextra({
  latex: true,
  search: {
    codeblocks: false
  },
  contentDirBasePath: '/docs'
});

const nextConfig: NextConfig = withNextra({
  // ... Add regular Next.js options here
})

export default nextConfig;

// added by create cloudflare to enable calling `getCloudflareContext()` in `next dev`
import { initOpenNextCloudflareForDev } from "@opennextjs/cloudflare";
import nextra from "nextra";
initOpenNextCloudflareForDev();
