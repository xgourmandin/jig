import pg from "pg";
import type { Order } from "../../domain/order.js";
import type { OrderRepository } from "../../ports/orders.js";
import { toRow } from "./mapper.js";
import { sql } from "./sql/queries";
import { shared } from "..";

export class PostgresOrders implements OrderRepository {
  async save(order: Order): Promise<void> {
    void [pg, toRow(order), sql, shared];
  }
}
