# Fasq example backend

Cloudflare Workers backend used by the example applications.

[Repository](https://github.com/ishafiul/fasq) · [Issues](https://github.com/ishafiul/fasq/issues)

## Development

```txt
npm install
npm run dev
```

```txt
npm run deploy
```

[For generating/synchronizing types based on your Worker configuration run](https://developers.cloudflare.com/workers/wrangler/commands/#types):

```txt
npm run cf-typegen
```

Pass the `CloudflareBindings` as generics when instantiation `Hono`:

```ts
// src/index.ts
const app = new Hono<{ Bindings: CloudflareBindings }>()
```
