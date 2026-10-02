import { PlaceOrder } from "../application/place-order.js";
import { MemoryOrders } from "../adapters/memory/orders.js";

export const container = { placeOrder: new PlaceOrder(new MemoryOrders()) };
