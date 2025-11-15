const MODULES = ["post", "auth"] as const;
const ACTIONS = ["r", "rw"] as const;

export type PermissionString =
  | "user"
  | "superadmin"
  | `admin:${(typeof MODULES)[number]}:${(typeof ACTIONS)[number]}`;

export const roleMap: Record<string, PermissionString[]> = {
  user: ["user"],
  superadmin: ["superadmin"],
  adminAllRead: ["admin:post:r", "admin:auth:r"],
  adminAllWrite: ["admin:post:rw", "admin:auth:rw"],
};
