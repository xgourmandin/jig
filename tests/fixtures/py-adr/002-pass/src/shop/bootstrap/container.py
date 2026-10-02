from shop.adapters.postgres.orders import PostgresOrders
from shop.application.place_order import PlaceOrder

place_order = PlaceOrder(PostgresOrders())
