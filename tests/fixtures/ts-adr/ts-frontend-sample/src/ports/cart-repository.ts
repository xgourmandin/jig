import type { Cart } from "../domain/cart";

export interface CartRepository {
  load(): Promise<Cart>;
  save(cart: Cart): Promise<void>;
}
