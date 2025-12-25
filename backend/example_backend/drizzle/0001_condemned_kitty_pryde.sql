ALTER TABLE "auths" ADD COLUMN "is_trusted" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "auths" ADD COLUMN "trusted_at" timestamp;--> statement-breakpoint
ALTER TABLE "devices" ADD COLUMN "fingerprint" text;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "is_banned" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "banned_at" timestamp;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "banned_until" timestamp;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "ban_reason" text;--> statement-breakpoint
ALTER TABLE "devices" ADD CONSTRAINT "devices_fingerprint_unique" UNIQUE("fingerprint");