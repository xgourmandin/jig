import { randomUUID } from "node:crypto";
import { Money, Order } from "../domain/index.js";
import type { OrderRepository } from "../ports/orders.js";

export class PlaceOrder {
  constructor(private readonly orders: OrderRepository) {}

  async run(cents: number): Promise<string> {
    const order = new Order(randomUUID(), new Money(cents));
    await this.orders.save(order);
    return order.id;
  }
}
