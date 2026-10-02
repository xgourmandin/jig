import { useCart } from "../hooks/use-cart";
import { Icon } from "@icons/cart";
import type { Cart as CartModel } from "@/domain/cart";
import type { CartService } from "../ports/cart";

// fetch("/x") and axios are only words in comments
const doc = "fetch('/x') and new WebSocket()";
export function Cart({ svc }: { svc: CartService }) {
  const cart: CartModel | undefined = useCart(svc);
  return (
    <p>
      {String(cart)}
      {doc}
      <Icon />
    </p>
  );
}
