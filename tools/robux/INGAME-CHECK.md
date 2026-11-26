# In-game purchase check (Boss, 2026-11-26, by reading code; no Studio playtest, Hugo tests)

- Shop buy button: `src/client/UI/ShopScreen.luau:300-327` picks `PromptGamePassPurchase` for Kind "Pass", `PromptProductPurchase` for products, `PromptOnce` through the server for Once offers (Great White Pack); nothing is prompted while `Products.onSale` is false (Id 0 or Hidden).
- One `ProcessReceipt`: `src/server/Services/PurchaseService.luau:311` (the only assignment in `src/`); failed grants or saves return `NotProcessedYet` (`:83`, `:240`).
- Passes: owned on join through `UserOwnsGamePassAsync` with pcall and 4 tries (`:246-268`), live through `PromptGamePassPurchaseFinished` (`:291`); both call `PackService.pass`, which sets `PassDoubleOxygen`, read by `PackService.oxygenMult` (x2).
- Claim x3: `OfflineService.OpenTriple` -> `openPrompt` with a saved reservation (`PurchaseService.Init`); its button shows once `Products.Triple.Id` is real.
- Double Luck and Exclusive stay hidden and are not created (no buyer benefit defined).
- Icons: `tools/robux/icons/sheet.png` (15 icons, 512x512, looked at).
