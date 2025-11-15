import { ORPCError } from "@orpc/server";
import { openAPIGenerator } from "../config/handlers";
import { appRouter } from "../router";

export async function generateOpenApiSpec() {
  const document = await openAPIGenerator.generate(appRouter, {
    info: {
      title: "Fasq Example API",
      version: "1.0.0",
      description: "Fasq Example API",
    },
    servers: [
      {
        url: "/api",
      },
    ],
  });

  function ensureComponents(doc: any) {
    if (!doc.components) doc.components = {};
    if (!doc.components.schemas) doc.components.schemas = {};
    return doc.components.schemas as Record<string, any>;
  }

  const components = ensureComponents(document);

  function deepEqual(a: any, b: any): boolean {
    try {
      return JSON.stringify(a) === JSON.stringify(b);
    } catch {
      return false;
    }
  }

  function clone<T>(obj: T): T {
    return obj && typeof obj === 'object' ? JSON.parse(JSON.stringify(obj)) : (obj as any);
  }

  function hoistTopLevel(schema: any): any {
    if (!schema || typeof schema !== 'object') return schema;
    if (schema.$ref) return schema;

    function transformRec(node: any): any {
      if (!node || typeof node !== 'object') return node;
      if (node.$ref) return node;

      const nodeTitle = typeof node.title === 'string' ? node.title.trim() : '';
      const copy = clone(node);

      if (copy.properties && typeof copy.properties === 'object') {
        for (const key of Object.keys(copy.properties)) {
          copy.properties[key] = transformRec(copy.properties[key]);
        }
      }

      if (copy.items) {
        if (Array.isArray(copy.items)) {
          copy.items = copy.items.map((it: any) => transformRec(it));
        } else {
          copy.items = transformRec(copy.items);
        }
      }

      if (Array.isArray(copy.anyOf)) {
        copy.anyOf = copy.anyOf.map((s: any) => transformRec(s));
      }

      if (Array.isArray(copy.oneOf)) {
        copy.oneOf = copy.oneOf.map((s: any) => transformRec(s));
      }

      if (Array.isArray(copy.allOf)) {
        copy.allOf = copy.allOf.map((s: any) => transformRec(s));
      }

      if (copy.additionalProperties && typeof copy.additionalProperties === 'object') {
        copy.additionalProperties = transformRec(copy.additionalProperties);
      }

      if (nodeTitle) {
        if (!components[nodeTitle]) {
          components[nodeTitle] = copy;
        } else if (!deepEqual(components[nodeTitle], copy)) {
          throw new ORPCError('INTERNAL_SERVER_ERROR', {
            message: `Conflicting schema title '${nodeTitle}' with differing structure`,
          });
        }
        return { $ref: `#/components/schemas/${nodeTitle}` };
      }

      return copy;
    }

    return transformRec(schema);
  }

  function processOperation(op: any, operationId?: string) {
    if (!op || typeof op !== 'object') return;

    if (op.requestBody && op.requestBody.content) {
      for (const mt of Object.keys(op.requestBody.content)) {
        const media = op.requestBody.content[mt];
        if (media && media.schema) {
          if (!media.schema.title && operationId && media.schema.type === 'object') {
            media.schema.title = `${operationId}Request`;
          }
          media.schema = hoistTopLevel(media.schema);
        }
      }
    }

    if (op.responses) {
      for (const status of Object.keys(op.responses)) {
        if (!/^20\d$/.test(status)) continue;
        const resp = op.responses[status];
        if (resp && resp.content) {
          for (const mt of Object.keys(resp.content)) {
            const media = resp.content[mt];
            if (media && media.schema) {
              if (!media.schema.title && operationId && media.schema.type === 'object') {
                media.schema.title = `${operationId}Response`;
              }
              media.schema = hoistTopLevel(media.schema);
            }
          }
        }
      }
    }
  }

  if (document.paths) {
    for (const pathKey of Object.keys(document.paths)) {
      const pathItem = (document.paths as any)[pathKey];
      for (const methodKey of Object.keys(pathItem)) {
        const op = pathItem[methodKey];
        processOperation(op, op?.operationId);
      }
    }
  }

  return document;
}
