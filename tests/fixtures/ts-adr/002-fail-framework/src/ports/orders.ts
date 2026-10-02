import type { Order } from "../domain/order.js";
import axios from "axios";

export interface OrderRepository {
  save(order: Order): Promise<void>;
}
export const x = axios;
