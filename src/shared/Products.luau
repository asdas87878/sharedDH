--!strict
-- What the Shop sells for Robux (UI review 1, the user, 2026-11-22: the Shop is its own screen, laid out as the
-- reference's: one scrolling list of offers in sections). NONE IS ON SALE YET: no developer product or game pass has
-- been made, and none is made up here, so every Id is 0 and the Shop shows SOON on each. To put a Cash or Oxygen pack on
-- sale: make the developer product on the Roblox site and write its Id here (Products.onSale). Its price
-- is read from Roblox, so it is never other than what is charged. The server gives it (PurchaseService, kept by
-- SaveService); the client only asks Roblox for the prompt. The passes and the other offers have no grant yet.
-- The Oxygen and Cash packs' amounts and prices are the fixed ladder (the user, 2026-11-23: "Yes, show all": every pack
-- shown to everyone, none locked; docs/design/money.md, "Selling"). Price is what to set on the Roblox site.
--   Gives: what the server gives for it, "Coins" or "Oxygen" (max Oxygen, for good); Amount: how much, a whole number
--   Kind: "Product" (bought again and again) or "Pass" (bought once, kept)
--   Look: the card's colours, a name in Products.Looks
--   Picture: a name in UI.Kit's Textures, or nil for the card's big word (Big)
-- The sections run in this order down the Shop, the reference's (featured, packs, passes, then the boosts by size).
-- Featured has no offers of its own: it shows the one Oxygen pack that fits the player now (Pick; UI.ShopScreen says by
-- what rule).
-- "Oxygen" and "Cash" are what the stat rows' plus buttons open (StallController finds them by these titles).
--   Gives "Pack": a bundle (Pack), all of it in one receipt; Once: sold once an account, its button then says OWNED
--   Gives "DoubleOxygen": a pass, for good (PackService.oxygenMult)
--   Hidden: not shown (nothing is decided for it yet)
local Products = {}

export type Pack = {
	Oxygen: number,
	Coins: number,
	Fish: { { string } }, -- each { id, size, colour }
	Boost: number, -- seconds of the server's x2
}

export type Offer = {
	Key: string,
	Name: string,
	Kind: string,
	Id: number,
	Price: number, -- Robux, shown until Roblox has told the product's own price
	Gives: string?, -- "Coins" or "Oxygen"
	Amount: number?, -- how much of it
	Look: string,
	Picture: string?,
	Big: string?,
	Pack: Pack?,
	Once: boolean?,
	Hidden: boolean?,
	Fish: string?, -- the card's picture is this fish
	Line: string?, -- one short line under the name: what it does, only what is true
}

-- Colour: its title's (white without). Rail: its picture on the Shop's rail, a Kit texture or a big word.
-- Pick: the section whose pack for this player it shows
export type Section = {
	Title: string,
	Wide: boolean,
	Colour: Color3?,
	Rail: string,
	Pick: string?,
	Offers: { Offer },
}

-- The card colours: { top, bottom } of the gradient, vivid as the reference's
Products.Looks = {
	Gold = { Color3.fromRGB(255, 214, 72), Color3.fromRGB(255, 132, 24) },
	Sky = { Color3.fromRGB(96, 214, 255), Color3.fromRGB(36, 116, 236) },
	Berry = { Color3.fromRGB(255, 108, 176), Color3.fromRGB(196, 40, 120) },
	Grape = { Color3.fromRGB(190, 120, 255), Color3.fromRGB(110, 54, 220) },
	Lime = { Color3.fromRGB(150, 245, 80), Color3.fromRGB(40, 176, 60) },
	Sea = { Color3.fromRGB(70, 236, 214), Color3.fromRGB(16, 150, 170) },
}

Products.Sections = {
	{
		Title = "Packs",
		Wide = true,
		Rail = "Shop",
		Offers = {
			{
				-- (the user, 2026-11-25: the Great White remodel, +50K Oxygen, +$1M, an hour of x2 for the server; 149)
				Key = "Starter",
				Name = "Great White Pack",
				Kind = "Product",
				Gives = "Pack",
				Once = true,
				Id = 0,
				Price = 149,
				Pack = { Oxygen = 50_000, Coins = 1_000_000, Fish = { { "GreatWhite", "Colossal", "" } }, Boost = 3600 },
				Look = "Gold",
				Fish = "GreatWhite",
				Line = "Colossal Great White, +50K Oxygen, +$1M, 1 hour x2 Oxygen and Cash for the whole server",
			},
			{
				Key = "Exclusive",
				Hidden = true,
				Name = "Exclusive",
				Kind = "Product",
				Id = 0,
				Price = 0,
				Look = "Grape",
				Picture = "Shop",
			},
		},
	},
	{
		Title = "Featured",
		Wide = true,
		Colour = Color3.fromRGB(255, 214, 72),
		Rail = "★",
		Pick = "Oxygen",
		Offers = {},
	},
	{
		Title = "Passes",
		Wide = true,
		Rail = "x2",
		Offers = {
			{
				Key = "DoubleOxygen",
				Name = "Double Oxygen",
				Kind = "Pass",
				Gives = "DoubleOxygen",
				Line = "x2 Oxygen from your seahorse, for good",
				Id = 0,
				Price = 0,
				Look = "Sea",
				Picture = "Oxygen",
			},
			{
				Key = "DoubleLuck",
				Hidden = true,
				Name = "Double Luck",
				Kind = "Pass",
				Id = 0,
				Price = 0,
				Look = "Lime",
				Big = "x2",
			},
		},
	},
	{
		Title = "Oxygen",
		Wide = false,
		Rail = "Oxygen",
		Colour = Color3.fromRGB(96, 224, 255),
		Offers = {
			{
				Key = "Oxygen1",
				Name = "Small Tank",
				Kind = "Product",
				Gives = "Oxygen",
				Amount = 50_000,
				Id = 0,
				Price = 59,
				Look = "Sea",
				Picture = "Oxygen",
			},
			{
				Key = "Oxygen2",
				Name = "Medium Tank",
				Kind = "Product",
				Gives = "Oxygen",
				Amount = 500_000,
				Id = 0,
				Price = 149,
				Look = "Sea",
				Picture = "Oxygen",
			},
			{
				Key = "Oxygen3",
				Name = "Big Tank",
				Kind = "Product",
				Gives = "Oxygen",
				Amount = 5_000_000,
				Id = 0,
				Price = 349,
				Look = "Sea",
				Picture = "Oxygen",
			},
			{
				Key = "Oxygen4",
				Name = "Huge Tank",
				Kind = "Product",
				Gives = "Oxygen",
				Amount = 60_000_000,
				Id = 0,
				Price = 699,
				Look = "Sea",
				Picture = "Oxygen",
			},
			{
				Key = "Oxygen5",
				Name = "Giant Tank",
				Kind = "Product",
				Gives = "Oxygen",
				Amount = 800_000_000,
				Id = 0,
				Price = 1199,
				Look = "Sea",
				Picture = "Oxygen",
			},
			{
				Key = "Oxygen6",
				Name = "Colossal Tank",
				Kind = "Product",
				Gives = "Oxygen",
				Amount = 10_000_000_000,
				Id = 0,
				Price = 2249,
				Look = "Sea",
				Picture = "Oxygen",
			},
		},
	},
	{
		Title = "Cash",
		Wide = false,
		Rail = "Cash",
		Colour = Color3.fromRGB(120, 255, 96),
		Offers = {
			{
				Key = "Cash1",
				Name = "Handful of Cash",
				Kind = "Product",
				Gives = "Coins",
				Amount = 1_000_000,
				Id = 0,
				Price = 49,
				Look = "Lime",
				Picture = "Cash",
			},
			{
				Key = "Cash2",
				Name = "Pile of Cash",
				Kind = "Product",
				Gives = "Coins",
				Amount = 25_000_000,
				Id = 0,
				Price = 99,
				Look = "Lime",
				Picture = "Cash",
			},
			{
				Key = "Cash3",
				Name = "Bag of Cash",
				Kind = "Product",
				Gives = "Coins",
				Amount = 1_000_000_000,
				Id = 0,
				Price = 199,
				Look = "Lime",
				Picture = "Cash",
			},
			{
				Key = "Cash4",
				Name = "Crate of Cash",
				Kind = "Product",
				Gives = "Coins",
				Amount = 50_000_000_000,
				Id = 0,
				Price = 399,
				Look = "Lime",
				Picture = "Cash",
			},
			{
				Key = "Cash5",
				Name = "Chest of Cash",
				Kind = "Product",
				Gives = "Coins",
				Amount = 2_000_000_000_000,
				Id = 0,
				Price = 699,
				Look = "Lime",
				Picture = "Cash",
			},
			{
				Key = "Cash6",
				Name = "Vault of Cash",
				Kind = "Product",
				Gives = "Coins",
				Amount = 75_000_000_000_000,
				Id = 0,
				Price = 1299,
				Look = "Lime",
				Picture = "Cash",
			},
		},
	},
} :: { Section }

-- Claim x3 in the Welcome back window (Hugo, 2026-11-25: 29 Robux; docs/design/offline-rewards.md). Not in Sections: the
-- Shop never lists it, and while its Id is 0 the window has no button for it. Amount: this many times what is owed, the
-- server's own number at the receipt (OfflineService.triple)
Products.Triple = {
	Key = "OfflineTriple",
	Name = "Claim x3",
	Kind = "Product",
	Gives = "Offline",
	Amount = 3,
	Id = 0,
	Price = 29,
	Look = "Gold",
} :: Offer

-- Whether an offer can be bought: it has a product, and the server has something to give for it
function Products.onSale(offer: Offer): boolean
	if offer.Id <= 0 or offer.Gives == nil or offer.Hidden then
		return false
	elseif offer.Kind == "Pass" then
		return true
	end
	local amount = offer.Amount
	return offer.Pack ~= nil or (amount ~= nil and amount > 0)
end

-- The part of the save each thing given is kept in (SaveService; the player's attribute "Saved" .. part says it is on)
Products.Part = { Coins = "Tank", Oxygen = "Oxygen", Pack = "Packs", Offline = "Offline" } :: { [string]: string }

-- The offer a Roblox product is (the server's: a receipt's ProductId)
function Products.byId(id: number, kind: string?): Offer?
	if id > 0 and Products.Triple.Id == id and Products.Triple.Kind == (kind or "Product") then
		return Products.Triple
	end
	for _, section in Products.Sections do
		for _, offer in section.Offers do
			if id > 0 and offer.Id == id and offer.Kind == (kind or "Product") then
				return offer
			end
		end
	end
	return nil
end

return Products
