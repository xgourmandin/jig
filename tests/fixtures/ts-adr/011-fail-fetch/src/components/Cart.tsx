import { useEffect } from "react";
export function Cart() {
  useEffect(() => {
    fetch("/api/cart").then((r) => r.json());
  }, []);
  return <p>cart</p>;
}
