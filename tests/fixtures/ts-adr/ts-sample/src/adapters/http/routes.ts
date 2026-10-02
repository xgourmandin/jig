import express from "express";
import type { PlaceOrder } from "../../application/place-order.js";

export function routes(placeOrder: PlaceOrder) {
  const app = express();
  app.post("/orders", async (_req, res) => {
    res.json({ id: await placeOrder.run(100) });
  });
  return app;
}
