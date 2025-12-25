export const ALLOWED_IMAGE_TYPES = [
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/gif',
] as const;

export type AllowedImageType = typeof ALLOWED_IMAGE_TYPES[number];

export const MAX_IMAGE_SIZE = 10 * 1024 * 1024;

export function validateImageMetadata(
  contentType: string,
  fileSize: number
): { valid: boolean; error?: string } {
  // Type guard to check if contentType is in the allowed types
  if (!ALLOWED_IMAGE_TYPES.includes(contentType as AllowedImageType)) {
    return {
      valid: false,
      error: `Invalid file type. Allowed types: ${ALLOWED_IMAGE_TYPES.join(', ')}`,
    };
  }

  if (fileSize > MAX_IMAGE_SIZE) {
    return {
      valid: false,
      error: `File size exceeds maximum limit of ${MAX_IMAGE_SIZE / 1024 / 1024}MB`,
    };
  }

  return { valid: true };
}

export function generateProductImageKey(
  vendorId: string,
  productId: string,
  filename: string
): string {
  const timestamp = Date.now();
  const sanitizedFilename = filename.replace(/[^a-zA-Z0-9.-]/g, '_');
  return `products/${vendorId}/${productId}/${timestamp}-${sanitizedFilename}`;
}

export function generateVendorLogoKey(
  vendorId: string,
  filename: string
): string {
  const timestamp = Date.now();
  const sanitizedFilename = filename.replace(/[^a-zA-Z0-9.-]/g, '_');
  return `vendors/${vendorId}/logo/${timestamp}-${sanitizedFilename}`;
}

export function generateCategoryImageKey(
  categoryId: string,
  filename: string
): string {
  const timestamp = Date.now();
  const sanitizedFilename = filename.replace(/[^a-zA-Z0-9.-]/g, '_');
  return `categories/${categoryId}/${timestamp}-${sanitizedFilename}`;
}

export function generatePromotionalImageKey(
  promotionalId: string,
  filename: string
): string {
  const timestamp = Date.now();
  const sanitizedFilename = filename.replace(/[^a-zA-Z0-9.-]/g, '_');
  return `promotional/${promotionalId}/${timestamp}-${sanitizedFilename}`;
}

export async function generateUploadToken(
  key: string,
  expiresIn: number = 3600
): Promise<{ token: string; expiresAt: number }> {
  const expiresAt = Date.now() + expiresIn * 1000;
  const token = btoa(JSON.stringify({ key, expiresAt }));
  return { token, expiresAt };
}

/**
 * Deletes an object from the specified R2 bucket by key.
 * Throws if deletion fails. Handles missing type reference for `R2Bucket`.
 * @param key Object key to delete.
 * @param bucket Cloudflare R2 bucket. Should conform to the minimal R2Bucket shape ({ delete(key: string): Promise<any> }).
 */
export async function deleteFromR2(
  key: string,
  bucket: { delete(key: string): Promise<void> },
): Promise<void> {
  if (!bucket || typeof bucket.delete !== 'function') {
    throw new Error('Invalid R2 bucket: delete method not found.');
  }
  try {
    await bucket.delete(key);
  } catch (error) {
    throw new Error(`Failed to delete key "${key}" from R2 bucket: ${(error as Error).message}`);
  }
}

export function getPublicUrl(r2PublicUrl: string, key: string): string {
  return `${r2PublicUrl}/${key}`;
}

export function extractKeyFromUrl(
  r2PublicUrl: string,
  url: string
): string | null {
  const prefix = `${r2PublicUrl}/`;
  if (url.startsWith(prefix)) {
    return url.substring(prefix.length);
  }
  return null;
}

