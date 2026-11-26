# Set up the Ride a Fish Robux catalog

Run from the checkout that will be published. Python 3.10+ on Linux is enough. The tool uses the standard library HTTP client.

```sh
python3 tools/robux/setup.py --dry-run
```

Dry run prints the offer, price, icon, and the conditions for creating or reusing it. It makes zero HTTP requests and writes no files. With no universe file it prints the URL template. It cannot tell which offers already exist in Roblox without reading the live catalog. A plain invocation also defaults to dry run.

## Apply after publishing the experience

1. In Creator Hub, create an API key under the account that manages Ride a Fish. Restrict it to the published Ride a Fish experience and grant `developer-product:read`, `developer-product:write`, `game-pass:read`, and `game-pass:write`. [API key setup](https://create.roblox.com/docs/cloud/auth/api-keys) · [Scopes](https://create.roblox.com/docs/cloud/reference/scopes)
2. Save just the API key in `~/.config/ride-a-fish/roblox-key` with mode `600`. Save the experience's numeric **universe ID** in `~/.config/ride-a-fish/universe-id`. Creator Hub's experience menu has **Copy Universe ID**. [Find an experience ID](https://create.roblox.com/docs/cloud/guides/instance)
3. Run `python3 tools/robux/setup.py --apply`. Check the resulting `git diff -- src/shared/Products.luau`, then publish the game with the populated IDs so in-game prompts and grants can use them.

The tool creates or reuses 14 developer products and one pass. Hidden offers are skipped. It includes Claim x3 from the Welcome Back window even though it lives outside the shop sections. Create uploads the matching 512×512 PNG and marks the offer for sale at its configured Robux price. Existing offers are matched by configured ID and name, or by a unique case-insensitive name within the same universe and offer type. The tool updates changed sale fields and fills missing icons. Use `--apply --replace-icons` if reused offers already have icons you want to replace. This sets the base prices and disables managed pricing for these offers. External storefront listing is controlled separately in Creator Hub. [Developer product sales](https://create.roblox.com/docs/production/monetization/developer-products#enable-external-sales)

The Great White Pack's one-per-account button is enforced by the in-game Shop. Keep the Great White Pack and Claim x3 unlisted for external sale. Claim x3 requires a Welcome Back reward currently owed by the server.

The tool records Roblox IDs in `Products.luau` once the full run succeeds. If a run stops after an API write, first check Creator Hub for the last item and rerun from the same checkout when it is visible. Reconciliation reads every page before issuing any write and refuses ambiguous name matches or a configured ID that belongs to another offer. To resolve a duplicate name, fill in the intended ID from Creator Hub before rerunning.

## Open Cloud contract

The base URL is `https://apis.roblox.com` and the key goes in the `x-api-key` header.

| Offer type | Base path |
| --- | --- |
| Developer product | `/developer-products/v2/universes/{universeId}/developer-products` |
| Game pass | `/game-passes/v1/universes/{universeId}/game-passes` |

List with `GET {base}/creator` and follow `nextPageToken` using the `pageToken` query parameter. Create with `POST {base}` and update with `PATCH {base}/{id}`. POST returns `productId` or `gamePassId`. PATCH succeeds with HTTP 204. Writes use separate `multipart/form-data` fields `name`, `description`, `price`, `isForSale`, `isManagedPricingEnabled` and, for an icon upload, the binary `imageFile` part. [Developer Products API](https://create.roblox.com/docs/cloud/reference/features/developer-products.md) · [Game Passes API](https://create.roblox.com/docs/cloud/reference/features/game-passes.md)
