import type { Order } from "../../domain/order.js";

export abstract class BaseRepo {
  abstract save(order: Order): Promise<void>;
}
