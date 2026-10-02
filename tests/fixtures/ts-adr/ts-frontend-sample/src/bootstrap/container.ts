import { HttpCartRepository } from "../adapters/http/cart-api";
import { createCartService } from "../application/add-to-cart";
import { config } from "../config";

export const container = { cart: createCartService(new HttpCartRepository(config.apiUrl)) };
