import { MemoryOrders } from "../adapters/memory/orders.js";
import { routes } from "../adapters/http/routes.js";
import { PlaceOrder } from "../application/place-order.js";

export function build(env: NodeJS.ProcessEnv = process.env) {
  const placeOrder = new PlaceOrder(new MemoryOrders());
  return { app: routes(placeOrder), port: Number(env.PORT ?? 3000) };
}
