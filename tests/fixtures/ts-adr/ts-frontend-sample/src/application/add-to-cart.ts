import { Observable, of } from "rxjs";
import { Cart, type Item } from "@/domain/cart";
import type { CartRepository } from "@/ports/cart-repository";

export interface CartService {
  add(item: Item): Promise<Cart>;
  current(): Observable<number>;
}

export function createCartService(repo: CartRepository): CartService {
  return {
    async add(item) {
      const cart = (await repo.load()).add(item);
      await repo.save(cart);
      return cart;
    },
    current: () => of(0),
  };
}
