import type { Order } from "../domain/order.js";

export interface OrderRepository {
  save(order: Order): Promise<void>;
}

export abstract class Clock {
  abstract now(): Date;
}

// export class FakePort {}
const doc = "class OrderRepository {}";
export class PortAdapterHelper {
  doc = doc;
}
