import { render } from "@testing-library/react";
import { HttpCartRepository } from "../adapters/http/cart-api";
import CartButton from "./CartButton";

test("tests may import anything", () => {
  render(<CartButton sku="a" />);
  expect(new HttpCartRepository("/x")).toBeTruthy();
});
