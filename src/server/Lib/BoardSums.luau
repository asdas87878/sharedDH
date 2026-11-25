--!strict
-- The leaderboards' sums (LeaderboardService), apart so that tools/boards/board_test.luau can run them with no Studio.
--
-- A number as it is stored. An OrderedDataStore keeps whole numbers only, and a Luau number is whole to the last one
-- only up to 2^53 (9.007e15), while coins can pass that. So what is stored is a "mark", a whole number that is always
-- under 2^53 and always in the same order as the numbers themselves:
--   up to 1e15 steps     the mark is the number itself, in whole steps (a step is 1 / Scale: 1, or a tenth of a coin).
--                        It is rounded DOWN to a step, so nobody is listed with more than they have.
--   past 1e15 steps      1e15 + (log10(steps) - 15) x 1e13, rounded to the nearest whole. A power of ten is 1e13 marks, so
--                        the number read back is within 3e-13 of the one stored (12 figures; a board shows four). Two
--                        numbers nearer each other than that share a mark, and so a place.
-- The largest number there is (1.8e308) has the mark 3.93e15, less than half of 2^53. Nothing stored for 0 or less,
-- or for what is not a number: such a player has no place on a board.
local BoardSums = {}

local LINE = 1e15 -- steps up to here are kept one by one
local DECADE = 1e13 -- marks to a power of ten past it
local SLACK = 1e-6 -- (0.3 x 10 is 3 and not 2.9999999999999996)

export type Entry = { Id: number, Mark: number }
export type Place = { Id: number, Mark: number, Rank: number }

-- The mark of a number; nil: it has no place on a board
function BoardSums.mark(value: any, scale: number): number?
	if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
		return nil
	end
	local steps = value * scale
	if steps < LINE then
		local whole = math.floor(steps + SLACK)
		return if whole >= 1 then whole else nil
	end
	-- (the two logs apart only where the product itself would be past the largest number there is)
	local log = if steps < math.huge then math.log10(steps) else math.log10(value) + math.log10(scale)
	return LINE + math.floor((log - 15) * DECADE + 0.5)
end

-- The number of a mark, as a board shows it
function BoardSums.value(mark: number, scale: number): number
	if mark <= LINE then
		return mark / scale
	end
	return 10 ^ ((mark - LINE) / DECADE + 15) / scale
end

-- What Roblox's store handed over, as entries: anything that is not a player's id with a mark is left out
function BoardSums.read(page: { any }): { Entry }
	local list: { Entry } = {}
	for _, item in page do
		local id, mark = tonumber(item.key), item.value
		if id and id % 1 == 0 and type(mark) == "number" and mark >= 1 and mark < 2 ^ 53 then
			table.insert(list, { Id = id, Mark = mark })
		end
	end
	return list
end

-- The stored list and this server's own players (who are ahead of it) as one: the biggest first, on a tie the older
-- account (the smaller id), so a tie never flickers. Equal numbers share a rank and the next is as far down as they
-- are many (1, 2, 2, 4). `hidden` is left out, and only the first `keep` stay.
function BoardSums.places(
	stored: { Entry },
	here: { [number]: number }, -- id -> mark; 0: here, with nothing to show (off the board, whatever is stored)
	hidden: { number },
	keep: number
): { Place }
	local list: { Place } = {}
	local had: { [number]: boolean } = {}
	for _, id in hidden do
		had[id] = true
	end
	for id, mark in here do
		if not had[id] then
			had[id] = true
			if mark > 0 then
				table.insert(list, { Id = id, Mark = mark, Rank = 0 })
			end
		end
	end
	for _, entry in stored do
		if not had[entry.Id] then
			had[entry.Id] = true
			table.insert(list, { Id = entry.Id, Mark = entry.Mark, Rank = 0 })
		end
	end
	table.sort(list, function(a, b)
		if a.Mark ~= b.Mark then
			return a.Mark > b.Mark
		end
		return a.Id < b.Id
	end)
	for i = #list, keep + 1, -1 do
		list[i] = nil
	end
	for i, place in list do
		local before = list[i - 1]
		place.Rank = if before and before.Mark == place.Mark then before.Rank else i
	end
	return list
end

-- How long to wait after `fails` failed requests in a row
function BoardSums.backoff(fails: number, first: number, most: number): number
	return math.min(first * 2 ^ math.max(fails - 1, 0), most)
end

return BoardSums
