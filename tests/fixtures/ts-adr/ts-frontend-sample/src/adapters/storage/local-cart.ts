import { Cart } from "../../domain/cart";
import type { CartRepository } from "../../ports/cart-repository";

export class LocalCartRepository implements CartRepository {
  async load(): Promise<Cart> {
    return new Cart(JSON.parse(window.localStorage.getItem("cart") ?? "[]"));
  }
  async save(cart: Cart): Promise<void> {
    localStorage.setItem("cart", JSON.stringify(cart.items));
  }
}
