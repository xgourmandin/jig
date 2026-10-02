import { createRoot } from "react-dom/client";
import { App } from "./App";
import { container } from "./bootstrap/container";
import { CartProvider } from "./features/cart/CartProvider";

createRoot(document.getElementById("root")!).render(
  <CartProvider service={container.cart}>
    <App />
  </CartProvider>,
);
