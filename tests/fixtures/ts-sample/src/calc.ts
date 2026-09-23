export function add(a: number, b: number): number {
  return a + b;
}

export function mean(values: readonly number[]): number {
  if (values.length === 0) {
    throw new RangeError("mean of an empty list");
  }
  return values.reduce(add, 0) / values.length;
}
