export type Item = { sku: string; cents: number };

export class Cart {
  constructor(readonly items: readonly Item[] = []) {}
  add(item: Item): Cart {
    return new Cart([...this.items, item]);
  }
  total(): number {
    return this.items.reduce((sum, i) => sum + i.cents, 0) / 100;
  }
}
