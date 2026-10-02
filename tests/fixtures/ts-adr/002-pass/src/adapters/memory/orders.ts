import type { Order } from "../../domain/order.js";
import type { OrderRepository } from "../../ports/orders.js";

export class MemoryOrders implements OrderRepository {
  async save(_order: Order): Promise<void> {}
}
