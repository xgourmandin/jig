import os

from shop.adapters.memory.orders import InMemoryOrders
from shop.application.place_order import PlaceOrder

ENV = os.getenv("ENV", "dev")
place_order = PlaceOrder(InMemoryOrders())
