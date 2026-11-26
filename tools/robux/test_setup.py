"""Offline staging and activation regression checks."""

from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import setup


class FakeCloud:
    universe = "123"

    def __init__(self):
        self.items = {kind: {} for kind in setup.API}
        self.writes = []

    def catalog(self, kind):
        return list(self.items[kind].values())

    def request(self, method, path, fields, icon=None):
        self.writes.append((method, fields.copy(), icon))
        kind = next(kind for kind in setup.API if path.startswith(setup.endpoint(kind, self.universe)))
        _, _, id_field, icon_field = setup.API[kind]
        items = self.items[kind]
        if method == "POST":
            offer_id = len(items) + 101
            items[offer_id] = {id_field: offer_id}
        else:
            offer_id = int(path.rsplit("/", 1)[1])
        offer = items[offer_id]
        for field, value in fields.items():
            if field == "price":
                offer["priceInformation"] = {"defaultPriceInRobux": int(value)}
            elif field in {"isForSale", "isManagedPricingEnabled"}:
                offer[field] = value == "true"
            else:
                offer[field] = value
        if icon is not None:
            offer[icon_field] = 999
        return offer if method == "POST" else {}


class CatalogTest(unittest.TestCase):
    def test_stage_publish_activate(self):
        source = setup.PRODUCTS.read_text(encoding="utf-8")
        offers, _ = setup.load_offers(source)
        cloud = FakeCloud()
        starter = offers[0]
        route = setup.endpoint(starter.kind, cloud.universe)
        cloud.request("POST", route, {"name": starter.name, "isForSale": "true"}, starter.icon)
        cloud.writes.clear()
        with redirect_stdout(StringIO()):
            ids = setup.stage(cloud, setup.reconcile(offers, cloud), replace_icons=False)
        self.assertEqual(len(ids), 15)
        self.assertEqual(cloud.writes[0], (
            "PATCH",
            {
                "description": starter.description,
                "price": "49",
                "isForSale": "false",
                "isManagedPricingEnabled": "false",
            },
            None,
        ))
        self.assertTrue(all(fields.get("isForSale") == "false" for _, fields, _ in cloud.writes))
        self.assertTrue(all(not item["isForSale"] for kind in setup.API for item in cloud.catalog(kind)))

        with tempfile.TemporaryDirectory() as scratch:
            checkout = Path(scratch) / "Products.luau"
            checkout.write_text(source, encoding="utf-8")
            with patch.object(setup, "PRODUCTS", checkout):
                setup.write_ids(source, offers, ids)
            configured, _ = setup.load_offers(checkout.read_text(encoding="utf-8"))

        cloud.writes.clear()
        with self.assertRaisesRegex(setup.SetupError, "publish"):
            setup.activate(cloud, setup.reconcile(offers, cloud))
        self.assertFalse(cloud.writes)
        plan = setup.reconcile(configured, cloud)
        last_offer, last_remote = plan[-1]
        last_remote["priceInformation"]["defaultPriceInRobux"] += 1
        with self.assertRaisesRegex(setup.SetupError, "differs from staging"):
            setup.activate(cloud, plan)
        self.assertFalse(cloud.writes)

        last_remote["priceInformation"]["defaultPriceInRobux"] = last_offer.price
        with redirect_stdout(StringIO()):
            setup.activate(cloud, plan)
            setup.activate(cloud, plan)
        self.assertEqual(cloud.writes, [("PATCH", {"isForSale": "true"}, None)] * 15)
        self.assertTrue(all(item["isForSale"] for kind in setup.API for item in cloud.catalog(kind)))


if __name__ == "__main__":
    unittest.main()
