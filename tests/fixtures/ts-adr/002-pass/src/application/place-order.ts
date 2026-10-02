import { randomUUID } from "node:crypto";
import { Order } from "../domain/order.js";
import type { OrderRepository } from "../ports/orders.js";

export class PlaceOrder {
  constructor(private readonly repo: OrderRepository) {}
  async run(): Promise<string> {
    const id = randomUUID();
    await this.repo.save(new Order(id));
    return id;
  }
}
