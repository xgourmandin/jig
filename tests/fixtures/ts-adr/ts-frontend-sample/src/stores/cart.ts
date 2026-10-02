import { defineStore } from "pinia";
import type { Item } from "@/domain/cart";

export const useCartStore = defineStore("cart", {
  state: () => ({ items: [] as Item[] }),
});
