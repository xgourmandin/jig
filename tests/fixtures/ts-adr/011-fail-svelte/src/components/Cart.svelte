<script lang="ts">
  import { PgCart } from "../adapters/postgres/cart";
  let cart = PgCart;
</script>

<p>{cart}</p>
