import { authRoutes } from './routes/auth.route';
import { vendorRoutes } from './routes/vendor.route';
import { categoryRoutes } from './routes/category.route';
import { productRoutes } from './routes/product.route';
import { cartRoutes } from './routes/cart.route';
import { addressRoutes } from './routes/address.route';
import { orderRoutes } from './routes/order.route';
import { reviewRoutes } from './routes/review.route';
import { promoRoutes } from './routes/promo.route';
import { promotionalRoutes } from './routes/promotional.route';
import { paymentRoutes } from './routes/payment.route';

export const appRouter = {
  auth: authRoutes,
  vendor: vendorRoutes,
  category: categoryRoutes,
  product: productRoutes,
  cart: cartRoutes,
  address: addressRoutes,
  order: orderRoutes,
  review: reviewRoutes,
  promo: promoRoutes,
  promotional: promotionalRoutes,
  payment: paymentRoutes,
};
