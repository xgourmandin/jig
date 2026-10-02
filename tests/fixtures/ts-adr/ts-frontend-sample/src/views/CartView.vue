<template>
  <section>
    <!-- fetch("/x") in the template is not scanned; text: import axios from "axios" -->
    <button @click="add">add</button>
    <p>{{ store.items.length }}</p>
  </section>
</template>

<script setup lang="ts">
import { inject } from "vue";
import { useCartStore } from "../stores/cart";
import type { CartService } from "@/application/add-to-cart";

const store = useCartStore();
const svc = inject<CartService>("cart");
const add = (): void => {
  void svc?.add({ sku: "a", cents: 1 });
};
</script>

<style scoped>
section {
  color: red;
}
</style>
