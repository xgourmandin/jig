import { useCallback } from "react";
import { useCartService } from "@/features/cart/CartProvider";
import type { Item } from "@/domain/cart";

export function useAdd() {
  const svc = useCartService();
  return useCallback((item: Item) => svc.add(item), [svc]);
}
