def a(x, items=None, tag="[]", sep=",", t=(), n: int = 0, d=dict):
    items = [] if items is None else items
    # def z(q=[]): ...
    return items, ["x"], {"y": 1}


def b(cb=lambda v: v == 1, eq=1 == 1):
    try:
        return 1
    except Exception:
        return 0
    except (KeyError, ValueError):
        raise


# archgate-ignore PY-006/no-mutable-default-args sentinel shared on purpose
def c(x, items=[]):
    return items
