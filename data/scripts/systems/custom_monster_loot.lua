-- Drops custom loot for all monsters
local allLootConfig = {
	{ id = 6526, chance = 100000, minCount = 1, maxCount = 10 }, -- Example of loot (100% chance)
}

-- Custom loot for specific monsters (this has the same usage options as normal monster loot)
local customLootConfig = {
	["Dragon"] = { items = {
		{ name = "platinum coin", chance = 1000, maxCount = 1 },
	} },
}

local function buildLootEntry(entry)
	if not entry then
		return nil
	end

	local loot = Loot()

	if entry.id then
		loot:setId(entry.id)
	elseif entry.name then
		loot:setIdFromName(entry.name)
	end

	if entry.chance then
		loot:setChance(entry.chance)
	end

	if entry.minCount then
		loot:setMinCount(entry.minCount)
	end

	if entry.maxCount then
		loot:setMaxCount(entry.maxCount)
	end

	if entry.subType or entry.charges then
		loot:setSubType(entry.subType or entry.charges)
	end

	if entry.actionId or entry.aid then
		loot:setActionId(entry.actionId or entry.aid)
	end

	if entry.text or entry.description then
		loot:setText(entry.text or entry.description)
	end

	if entry.unique ~= nil then
		loot:setUnique(entry.unique)
	end

	if entry.children then
		for _, childEntry in ipairs(entry.children) do
			local childLoot = buildLootEntry(childEntry)
			if childLoot then
				loot:addChildLoot(childLoot)
			end
		end
	end

	return loot
end

local function addLootToMonster(mtype, lootConfig)
	if not mtype or not lootConfig then
		return
	end

	for _, entry in ipairs(lootConfig) do
		local loot = buildLootEntry(entry)
		if loot then
			mtype:addLoot(loot)
		end
	end
end

local customMonsterLoot = GlobalEvent("CreateCustomMonsterLoot")

function customMonsterLoot.onStartup()
	for monsterName, lootTable in pairs(customLootConfig) do
		local mtype = Game.getMonsterTypeByName(monsterName)
		if mtype then
			if lootTable and lootTable.items and #lootTable.items > 0 then
				addLootToMonster(mtype, lootTable.items)
				logger.debug("[customMonsterLoot.onStartup] - Custom loot registered for monster: {}", mtype:getName())
			end
		else
			logger.error("[customMonsterLoot.onStartup] - Monster type not found: {}", monsterName)
		end
	end

	if #allLootConfig > 0 then
		for monsterName, mtype in pairs(Game.getMonsterTypes()) do
			addLootToMonster(mtype, allLootConfig)
			logger.debug("[customMonsterLoot.onStartup] - Global loot registered for monster: {}", mtype:getName())
		end
	end
end

customMonsterLoot:register()
