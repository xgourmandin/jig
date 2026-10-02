from shop.domain.order import Order


class InMemoryOrders:
    def __init__(self) -> None:
        self.items: dict[str, Order] = {}

    def add(self, order: Order) -> None:
        self.items[order.id] = order
