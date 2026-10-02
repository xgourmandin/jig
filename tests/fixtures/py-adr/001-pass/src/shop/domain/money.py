from dataclasses import dataclass


@dataclass(frozen=True)
class Money:
    cents: int
