import { SelectPromoCode } from '../schemas/promo.schema';
import { SelectCartItem } from '../schemas/cart.schema';
import { SelectOrderItem } from '../schemas/order.schema';

export interface OrderTotals {
  subtotal: string;
  discountAmount: string;
  shippingCost: string;
  taxAmount: string;
  total: string;
}

export interface CartItemWithPrice extends SelectCartItem {
  price: string;
}

export function calculateOrderTotals(
  cartItems: CartItemWithPrice[],
  promoCode: SelectPromoCode | null,
  shippingCost: number = 0,
  taxRate: number = 0
): OrderTotals {
  const subtotal = cartItems.reduce((sum, item) => {
    const itemPrice = parseFloat(item.priceAtAdd);
    return sum + itemPrice * item.quantity;
  }, 0);

  let discountAmount = 0;

  if (promoCode && promoCode.isActive) {
    const now = new Date();
    const validFrom = new Date(promoCode.validFrom);
    const validUntil = new Date(promoCode.validUntil);

    if (now >= validFrom && now <= validUntil) {
      if (promoCode.minOrderValue) {
        const minOrderValue = parseFloat(promoCode.minOrderValue);
        if (subtotal < minOrderValue) {
          promoCode = null;
        }
      }

      if (promoCode) {
        const discountValue = parseFloat(promoCode.discountValue);

        if (promoCode.discountType === 'percentage') {
          discountAmount = (subtotal * discountValue) / 100;
        } else if (promoCode.discountType === 'fixed') {
          discountAmount = discountValue;
        }

        if (promoCode.maxDiscountAmount) {
          const maxDiscount = parseFloat(promoCode.maxDiscountAmount);
          discountAmount = Math.min(discountAmount, maxDiscount);
        }

        discountAmount = Math.min(discountAmount, subtotal);
      }
    }
  }

  const subtotalAfterDiscount = subtotal - discountAmount;
  const taxAmount = subtotalAfterDiscount * taxRate;
  const total = subtotalAfterDiscount + shippingCost + taxAmount;

  return {
    subtotal: subtotal.toFixed(2),
    discountAmount: discountAmount.toFixed(2),
    shippingCost: shippingCost.toFixed(2),
    taxAmount: taxAmount.toFixed(2),
    total: total.toFixed(2),
  };
}

export function generateOrderNumber(): string {
  const timestamp = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).substring(2, 8).toUpperCase();
  return `ORD-${timestamp}-${random}`;
}

export interface VendorOrderGroup {
  vendorId: string;
  items: SelectOrderItem[];
  subtotal: number;
}

export function groupOrderItemsByVendor(orderItems: SelectOrderItem[]): VendorOrderGroup[] {
  const vendorGroups = new Map<string, VendorOrderGroup>();

  for (const item of orderItems) {
    const vendorId = item.vendorId;

    if (!vendorGroups.has(vendorId)) {
      vendorGroups.set(vendorId, {
        vendorId,
        items: [],
        subtotal: 0,
      });
    }

    const group = vendorGroups.get(vendorId)!;
    group.items.push(item);
    group.subtotal += parseFloat(item.totalPrice);
  }

  return Array.from(vendorGroups.values());
}

