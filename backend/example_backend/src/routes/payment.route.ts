import z from "zod/v3";
import { ORPCError } from '@orpc/server';
import { publicProcedure, protectedProcedure } from '../procedures';
import type { TRPCContext } from '../context';

const OPENAPI_TAG = 'Payment';

export const paymentRoutes = {
  createPaymentIntent: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'POST',
      path: '/payment/create-intent',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        orderId: z.string(),
        amount: z.number().min(0),
        currency: z.string().default('USD'),
      })
    )
    .output(
      z.object({
        paymentIntentId: z.string(),
        clientSecret: z.string(),
      })
    )
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;

      throw new ORPCError('NOT_IMPLEMENTED', {
        message: 'Payment integration not yet implemented. This is a placeholder for future Stripe/PayPal integration.',
      });
    }),

  handleWebhook: publicProcedure
    .route({
      method: 'POST',
      path: '/payment/webhook',
      tags: [OPENAPI_TAG],
    })
    .input(z.any())
    .output(z.object({ received: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;

      return { received: true };
    }),
};

