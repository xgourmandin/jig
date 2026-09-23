from pysample.calc import add, mean


def test_add() -> None:
    assert add(2, 3) == 5


def test_mean() -> None:
    assert mean([1.0, 2.0, 3.0]) == 2.0


def test_mean_empty() -> None:
    try:
        mean([])
    except ValueError:
        return
    raise AssertionError("expected ValueError")
