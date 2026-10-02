import type { Money } from "../../domain/money.js";
export interface PaymentGateway {
  charge(m: Money): Promise<void>;
}
