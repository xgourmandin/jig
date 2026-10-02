import { createContext, useContext, type ReactNode } from "react";
import type { CartService } from "@/application/add-to-cart";

const Ctx = createContext<CartService | null>(null);

export function CartProvider({ service, children }: { service: CartService; children: ReactNode }) {
  return <Ctx.Provider value={service}>{children}</Ctx.Provider>;
}

export function useCartService(): CartService {
  const svc = useContext(Ctx);
  if (!svc) throw new Error("CartProvider missing");
  return svc;
}
