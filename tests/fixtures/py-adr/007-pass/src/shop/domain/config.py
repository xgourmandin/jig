import os


def token() -> str:
    return os.environ["TOKEN"]


class C:
    def read(self):
        with open("x") as fh:
            print(fh.read())
        return os.getenv("A")


if __name__ == "__main__":
    print("demo")

NAME = "os.getenv('X')"
# print("x")
