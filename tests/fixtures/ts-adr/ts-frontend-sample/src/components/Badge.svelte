<script lang="ts">
  import type { Item } from "@/domain/cart";
  export let item: Item;
</script>

<span>{item.sku}</span>
