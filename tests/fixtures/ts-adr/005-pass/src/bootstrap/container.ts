import { PostgresOrders } from "../adapters/postgres/orders.js";

export const container = { orders: new PostgresOrders() };
