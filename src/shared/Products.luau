--!strict
-- What the Shop sells for Robux (UI review 1, the user, 2026-11-22: the Shop is its own screen, laid out as the
-- reference's: one scrolling list of offers in sections). NONE IS ON SALE YET: no developer product or game pass has
-- been made, and none is made up here, so every Id is 0 and the Shop shows SOON on each. To put a Cash or Oxygen pack on
-- sale: make the developer product on the Roblox site and write its Id and its Amount here (Products.onSale). Its price
-- is read from Roblox, so it is never other than what is charged. The server gives it (PurchaseService, kept by
-- SaveService); the client only asks Roblox for the prompt. The passes and the other offers have no grant yet.
--   Gives: what the server gives for it, "Coins" or "Oxygen" (max Oxygen, for good); Amount: how much, a whole number
--   Kind: "Product" (bought again and again) or "Pass" (bought once, kept)
--   Look: the card's colours, a name in Products.Looks
--   Picture: a name in UI.Kit's Textures, or nil for the card's big word (Big)
-- The sections run in this order down the Shop, the reference's (featured, packs, passes, then the boosts by size).
-- "Oxygen" and "Cash" are what the stat rows' plus buttons open (StallController finds them by these titles).
local Products = {}

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
	Line: string?, -- one short line under the name: what it does, only what is true
}

-- Colour: its title's (white without)
export type Section = { Title: string, Wide: boolean, Colour: Color3?, Offers: { Offer } }

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
		Title = "Featured",
		Wide = true,
		Offers = {
			{
				Key = "Featured",
				Name = "Featured",
				Kind = "Product",
				Id = 0,
				Price = 0,
				Look = "Gold",
				Picture = "Shop",
			},
		},
	},
	{
		Title = "Packs",
		Wide = true,
		Offers = {
			{
				Key = "Starter",
				Name = "Starter Pack",
				Kind = "Pass",
				Id = 0,
				Price = 0,
				Look = "Sky",
				Picture = "Shop",
			},
			{
				Key = "Exclusive",
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
		Title = "Passes",
		Wide = true,
		Offers = {
			{
				Key = "DoubleOxygen",
				Name = "Double Oxygen",
				Kind = "Pass",
				Id = 0,
				Price = 0,
				Look = "Sea",
				Picture = "Oxygen",
			},
			{
				Key = "DoubleLuck",
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
		Colour = Color3.fromRGB(96, 224, 255),
		Offers = {
			{
				Key = "Oxygen1",
				Name = "Small Tank",
				Kind = "Product",
				Gives = "Oxygen",
				Id = 0,
				Price = 0,
				Look = "Sea",
				Picture = "Oxygen",
			},
			{
				Key = "Oxygen2",
				Name = "Big Tank",
				Kind = "Product",
				Gives = "Oxygen",
				Id = 0,
				Price = 0,
				Look = "Sea",
				Picture = "Oxygen",
			},
			{
				Key = "Oxygen3",
				Name = "Huge Tank",
				Kind = "Product",
				Gives = "Oxygen",
				Id = 0,
				Price = 0,
				Look = "Sea",
				Picture = "Oxygen",
			},
		},
	},
	{
		Title = "Cash",
		Wide = false,
		Colour = Color3.fromRGB(120, 255, 96),
		Offers = {
			{
				Key = "Cash1",
				Name = "Pile of Cash",
				Kind = "Product",
				Gives = "Coins",
				Id = 0,
				Price = 0,
				Look = "Lime",
				Picture = "Cash",
			},
			{
				Key = "Cash2",
				Name = "Bag of Cash",
				Kind = "Product",
				Gives = "Coins",
				Id = 0,
				Price = 0,
				Look = "Lime",
				Picture = "Cash",
			},
			{
				Key = "Cash3",
				Name = "Vault of Cash",
				Kind = "Product",
				Gives = "Coins",
				Id = 0,
				Price = 0,
				Look = "Lime",
				Picture = "Cash",
			},
		},
	},
} :: { Section }

-- Whether an offer can be bought: it has a product, and the server has something to give for it
function Products.onSale(offer: Offer): boolean
	local amount = offer.Amount
	return offer.Id > 0 and offer.Kind == "Product" and offer.Gives ~= nil and amount ~= nil and amount > 0
end

-- The part of the save each thing given is kept in (SaveService; the player's attribute "Saved" .. part says it is on)
Products.Part = { Coins = "Tank", Oxygen = "Oxygen" } :: { [string]: string }

-- The offer a Roblox product is (the server's: a receipt's ProductId)
function Products.byId(id: number): Offer?
	for _, section in Products.Sections do
		for _, offer in section.Offers do
			if id > 0 and offer.Id == id then
				return offer
			end
		end
	end
	return nil
end

return Products
