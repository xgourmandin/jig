from shop.domain.order import Order
from shop.ports.orders import OrderRepository


class PlaceOrder:
    def __init__(self, orders: OrderRepository) -> None:
        self._orders = orders

    def __call__(self, order_id: str) -> Order:
        order = Order(order_id)
        try:
            self._orders.add(order)
        except KeyError:
            raise
        return order
