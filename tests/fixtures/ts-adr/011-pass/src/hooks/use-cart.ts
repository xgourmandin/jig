import { getCart } from "@/application/get-cart";
import type { CartService } from "../ports/cart";
export const useCart = (svc: CartService) => getCart(svc);
export const refetch = (client: { fetch(): void }) => client.fetch();
