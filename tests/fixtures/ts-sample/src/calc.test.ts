import { expect, test } from "vitest";
import { add, mean } from "./calc.js";

test("add", () => {
  expect(add(2, 3)).toBe(5);
});

test("mean", () => {
  expect(mean([1, 2, 3])).toBe(2);
  expect(() => mean([])).toThrow(RangeError);
});
