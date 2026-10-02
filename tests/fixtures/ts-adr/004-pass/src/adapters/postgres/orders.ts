import type { Order } from "../../domain/order.js";
import type { OrderRepository } from "../../ports/orders.js";

interface PgOptions {
  url: string;
}

export class PostgresOrderRepository implements OrderRepository {
  constructor(private readonly opts: PgOptions) {}
  async save(_order: Order): Promise<void> {
    void this.opts;
  }
}
