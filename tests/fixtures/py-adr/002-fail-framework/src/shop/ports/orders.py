from typing import Protocol
from fastapi import Request


class OrderRepository(Protocol):
    def get(self, request: Request) -> None: ...
