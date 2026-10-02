from typing import Protocol

from shop.domain.order import Order


class OrderRepository(Protocol):
    def add(self, order: Order) -> None: ...
