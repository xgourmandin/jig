// archgate-ignore TS-005/composition-root-in-bootstrap legacy entrypoint, moving to main in SHOP-30
import { PostgresOrders } from "./adapters/postgres/orders.js";

export const x = PostgresOrders;
