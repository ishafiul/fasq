import { Hono } from "hono";
import { Scalar } from "@scalar/hono-api-reference";
import { generateOpenApiSpec } from "../utils/opnapiparsing";

const docsRouter = new Hono();

docsRouter.get("/spec.json", async (c) => {
  const spec = await generateOpenApiSpec();
  console.log("Generated OpenAPI spec paths:", Object.keys(spec.paths || {}));
  console.log("Generated OpenAPI spec schemas:", Object.keys(spec.components?.schemas || {}));
  return c.json(spec);
});

docsRouter.get(
  "/",
  Scalar(() => {
    return {
      url: "/spec.json"
    };
  })
);


export default docsRouter;

