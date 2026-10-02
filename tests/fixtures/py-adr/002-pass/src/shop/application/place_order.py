from __future__ import annotations

from shop.domain.order import Order
from shop.ports.orders import OrderRepository
from . import helpers


class PlaceOrder:
    def __init__(self, orders: OrderRepository) -> None:
        self.orders = orders
