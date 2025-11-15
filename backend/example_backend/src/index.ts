import { Hono } from "hono";
import type { HonoTypes } from "./context";
import { rpcHandler, openAPIHandler } from "./config/handlers";
import { setupContext, getContextForHandler } from "./middleware/setup.middleware";
import docsRouter from "./routes/docs.route";

const app = new Hono<HonoTypes>();

app.use("*", setupContext);

app.use("/api/*", async (c, next) => {
  const context = getContextForHandler(c);

  const { matched, response } = await openAPIHandler.handle(c.req.raw, {
    prefix: "/api",
    context,
  });

  if (matched) {
    return c.newResponse(response.body, response);
  }

  await next();
});

app.use("/rpc/*", async (c, next) => {
  const context = getContextForHandler(c);

  const { matched, response } = await rpcHandler.handle(c.req.raw, {
    prefix: "/rpc",
    context,
  });

  if (matched) {
    return c.newResponse(response.body, response);
  }

  await next();
});

app.route("/", docsRouter);

export default app;
