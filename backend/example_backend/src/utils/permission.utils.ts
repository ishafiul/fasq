const MODULES = ["post", "auth", "vendor", "product", "category", "order", "review", "promo", "promotional"] as const;
const ACTIONS = ["r", "rw"] as const;

export type PermissionString =
  | "user"
  | "vendor"
  | "admin"
  | "superadmin"
  | `admin:${(typeof MODULES)[number]}:${(typeof ACTIONS)[number]}`
  | `vendor:${(typeof MODULES)[number]}:${(typeof ACTIONS)[number]}`;

export const roleMap: Record<string, PermissionString[]> = {
  user: ["user"],
  vendor: ["vendor", "vendor:product:rw", "vendor:order:r"],
  admin: ["admin", "admin:product:rw", "admin:category:rw", "admin:order:rw", "admin:review:rw", "admin:promo:rw", "admin:promotional:rw", "admin:vendor:rw"],
  superadmin: ["superadmin"],
};
