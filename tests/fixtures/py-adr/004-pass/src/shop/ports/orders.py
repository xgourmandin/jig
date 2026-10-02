import abc
from typing import Protocol


class OrderRepository(Protocol):
    def add(self, order: object) -> None: ...


class AuditedOrderRepository(OrderRepository, Protocol):
    pass


class Legacy(abc.ABC):
    pass


class SpecialRepository(OrderRepository):
    pass
