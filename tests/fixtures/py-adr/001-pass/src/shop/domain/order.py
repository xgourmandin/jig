"""Orders. Mentions import sqlalchemy and from shop.adapters import db in prose only."""
from __future__ import annotations

import dataclasses
from decimal import Decimal

from . import money
from .money import Money

# import requests   (a comment)
TEXT = "import boto3"


@dataclasses.dataclass
class Order:
    total: Money
    tax: Decimal
