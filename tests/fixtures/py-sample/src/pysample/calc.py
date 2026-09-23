"""Arithmetic helpers."""


def add(a: int, b: int) -> int:
    return a + b


def mean(values: list[float]) -> float:
    if not values:
        raise ValueError("mean of an empty list")
    return sum(values) / len(values)
