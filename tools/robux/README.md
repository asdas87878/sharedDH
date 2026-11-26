# Set up the Ride a Fish Robux catalog

Run from the checkout that will be published. Python 3.10+ on Linux is enough. The tool uses the standard library HTTP client.

```sh
python3 tools/robux/setup.py --dry-run
```

Dry run prints the offer, price, icon, and the conditions for creating or reusing it. It makes zero HTTP requests and writes no files. With no universe file it prints the URL template. It cannot tell which offers already exist in Roblox without reading the live catalog. A plain invocation also defaults to dry run.

## Stage, publish, then activate

1. In Creator Hub, create an API key under the account that manages Ride a Fish. Restrict it to the published Ride a Fish experience and grant `developer-product:read`, `developer-product:write`, `game-pass:read`, and `game-pass:write`. [API key setup](https://create.roblox.com/docs/cloud/auth/api-keys) · [Scopes](https://create.roblox.com/docs/cloud/reference/scopes)
2. Save just the API key in `~/.config/ride-a-fish/roblox-key` with mode `600`. Save the experience's numeric **universe ID** in `~/.config/ride-a-fish/universe-id`. Creator Hub's experience menu has **Copy Universe ID**. [Find an experience ID](https://create.roblox.com/docs/cloud/guides/instance)
3. Run `python3 tools/robux/setup.py --apply` to set up the offers **off sale**. This also turns matched offers off if they are already on sale. Review the IDs with `git diff -- src/shared/Products.luau`.
4. Keep Great White Pack and Claim x3 **unlisted** in Creator Hub → Monetization → Shop. Publish the game with the populated IDs and the purchase handlers from this branch. Confirm the updated build is in service before enabling sales.
5. Run `python3 tools/robux/setup.py --activate` to enable sales. This checks all local IDs and staged offer settings before issuing any sale changes. Publishing is a separate step that the tool relies on the operator to verify.

Staging creates or reuses 14 developer products and one pass. It includes Claim x3 from the Welcome Back window. Double Luck is deferred pending a defined buyer benefit, a price, and the required odds disclosures and eligibility checks. [Paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items)

Staging matches existing offers by ID and name, or by a unique case-insensitive name within the same universe and offer type. It sets base prices, disables managed pricing, and uploads the matching 512×512 PNG for each new offer and each reused offer that has no icon. Use `--apply --replace-icons` to replace icons on reused offers. Activation changes sale status only. Creator Hub controls external storefront listing separately. [Developer product sales](https://create.roblox.com/docs/production/monetization/developer-products#enable-external-sales)

Great White Pack and Claim x3 use a saved in-game reservation. After a disconnected prompt, the player can rejoin so Roblox can deliver any pending receipt. A purchase can stay pending if Roblox sends neither a cancellation nor a receipt. Claim x3 still allows the free reward after the hold timer, and a later receipt then grants the reserved bonus.

Staging records Roblox IDs in `Products.luau` once the full run succeeds. If staging or activation stops after an API write, check Creator Hub and rerun the same command from the same checkout. Reconciliation reads every page before issuing any write and refuses ambiguous name matches or a configured ID that belongs to another offer. To resolve a duplicate name, fill in the intended ID from Creator Hub before rerunning.

## Open Cloud contract

The base URL is `https://apis.roblox.com` and the key goes in the `x-api-key` header.

| Offer type | Base path |
| --- | --- |
| Developer product | `/developer-products/v2/universes/{universeId}/developer-products` |
| Game pass | `/game-passes/v1/universes/{universeId}/game-passes` |

List with `GET {base}/creator` and follow `nextPageToken` using the `pageToken` query parameter. Create with `POST {base}` and update with `PATCH {base}/{id}`. POST returns `productId` or `gamePassId`. PATCH succeeds with HTTP 204. Writes use separate `multipart/form-data` fields `name`, `description`, `price`, `isForSale`, `isManagedPricingEnabled` and, for an icon upload, the binary `imageFile` part. [Developer Products API](https://create.roblox.com/docs/cloud/reference/features/developer-products.md) · [Game Passes API](https://create.roblox.com/docs/cloud/reference/features/game-passes.md)
