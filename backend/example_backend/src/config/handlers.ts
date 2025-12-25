import { RPCHandler } from "@orpc/server/fetch";
import { onError } from "@orpc/server";
import { OpenAPIHandler } from "@orpc/openapi/fetch";
import { OpenAPIGenerator } from "@orpc/openapi";
import { CORSPlugin } from "@orpc/server/plugins";
import { ZodSmartCoercionPlugin, ZodToJsonSchemaConverter } from "@orpc/zod";

import { appRouter } from "../router";

export const rpcHandler = new RPCHandler(appRouter, {
  plugins: [new CORSPlugin(), new ZodSmartCoercionPlugin()],
  interceptors: [
    onError((error) => {
      console.error(error);
    }),
  ],
});

export const openAPIHandler = new OpenAPIHandler(appRouter, {
  plugins: [new CORSPlugin(), new ZodSmartCoercionPlugin()],
});

export const openAPIGenerator = new OpenAPIGenerator({
  schemaConverters: [new ZodToJsonSchemaConverter()],
});

