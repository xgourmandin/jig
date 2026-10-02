import axios from "axios";
import { Cart } from "../../domain/cart";
import type { CartRepository } from "../../ports/cart-repository";

export class HttpCartRepository implements CartRepository {
  constructor(private readonly baseUrl: string) {}
  async load(): Promise<Cart> {
    const res = await axios.get<{ items: [] }>(`${this.baseUrl}/cart`);
    return new Cart(res.data.items);
  }
  async save(cart: Cart): Promise<void> {
    await fetch(`${this.baseUrl}/cart`, { method: "PUT", body: JSON.stringify(cart.items) });
  }
}
