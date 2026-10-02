import { expect, test } from "vitest";
import { MemoryOrders } from "../adapters/memory/orders.js";
import { Money } from "./money.js";

test("tests may import anything", () => {
  expect(new MemoryOrders().saved).toEqual([]);
  expect(new Money(1).cents).toBe(1);
});
