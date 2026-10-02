import { Money } from "./money.js";

export class Order {
  constructor(
    readonly id: string,
    readonly total: Money,
  ) {}
}
