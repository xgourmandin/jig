import type { Order } from "../../domain/order.js";
import type { OrderRepository } from "../../ports/orders.js";

export class MemoryOrders implements OrderRepository {
  readonly saved: Order[] = [];
  async save(order: Order): Promise<void> {
    this.saved.push(order);
  }
}
