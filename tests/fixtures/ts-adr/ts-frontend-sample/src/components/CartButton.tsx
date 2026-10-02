import { useAdd } from "../hooks/use-add";

// Don't call fetch("/x") here; use the hook. 10 / 2 and a/b are just math: </p>
export default function CartButton({ sku }: { sku: string }) {
  const add = useAdd();
  const half = 10 / 2;
  return (
    <button onClick={() => add({ sku, cents: half })}>
      Don't wait: add {sku} / now
    </button>
  );
}
