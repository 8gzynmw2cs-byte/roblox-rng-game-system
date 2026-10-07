-- ServerScriptService/MainRNGSystem.server.lua
-- Core RNG system with weighted probability, economy rewards, and player data management
-- Designed for Sol's RNG style gameplay

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- DataStore initialization with versioning
local PLAYER_DATA_STORE = DataStoreService:GetDataStore("SolsRNGPlayerData_v2")
local LEADERBOARD_STORE = DataStoreService:GetDataStore("SolsRNGLeaderboard_v2")

-- ============================================================================
-- RARITY TIER DEFINITIONS
-- ============================================================================
-- Each tier defines: odds (1 in X), coin rewards, and 3 unique aura effects
local RarityTiers = {
	Common = {
		Name = "Common",
		Rank = 1,
		Odds = 2,                    -- 1 in 2 (50%)
		CoinReward = 1,
		Color = Color3.fromRGB(200, 200, 200),
		TextColor = Color3.fromRGB(180, 180, 180),
		Auras = {
			{
				Name = "Plain Glow",
				Color = Color3.fromRGB(200, 200, 200),
				Size = 3,
				Speed = 1,
			},
			{
				Name = "Dim Pulse",
				Color = Color3.fromRGB(150, 150, 150),
				Size = 2.5,
				Speed = 0.8,
			},
			{
				Name = "Gray Shimmer",
				Color = Color3.fromRGB(170, 170, 170),
				Size = 2,
				Speed = 1.2,
			},
		},
	},
	Uncommon = {
		Name = "Uncommon",
		Rank = 2,
		Odds = 5,                    -- 1 in 5 (20%)
		CoinReward = 5,
		Color = Color3.fromRGB(100, 200, 100),
		TextColor = Color3.fromRGB(80, 220, 80),
		Auras = {
			{
				Name = "Green Radiance",
				Color = Color3.fromRGB(100, 255, 100),
				Size = 4,
				Speed = 1.1,
			},
			{
				Name = "Mint Aura",
				Color = Color3.fromRGB(120, 240, 140),
				Size = 3.5,
				Speed = 1.3,
			},
			{
				Name = "Emerald Pulse",
				Color = Color3.fromRGB(90, 210, 120),
				Size = 3,
				Speed = 0.9,
			},
		},
	},
	Rare = {
		Name = "Rare",
		Rank = 3,
		Odds = 20,                   -- 1 in 20 (5%)
		CoinReward = 25,
		Color = Color3.fromRGB(100, 160, 255),
		TextColor = Color3.fromRGB(120, 180, 255),
		Auras = {
			{
				Name = "Azure Storm",
				Color = Color3.fromRGB(100, 180, 255),
				Size = 5,
				Speed = 1.2,
			},
			{
				Name = "Sapphire Glow",
				Color = Color3.fromRGB(80, 150, 240),
				Size = 4.5,
				Speed = 1.4,
			},
			{
				Name = "Crystalline Shimmer",
				Color = Color3.fromRGB(110, 170, 255),
				Size = 4,
				Speed = 1,
			},
		},
	},
	Epic = {
		Name = "Epic",
		Rank = 4,
		Odds = 100,                  -- 1 in 100 (1%)
		CoinReward = 100,
		Color = Color3.fromRGB(180, 100, 255),
		TextColor = Color3.fromRGB(200, 120, 255),
		Auras = {
			{
				Name = "Amethyst Flame",
				Color = Color3.fromRGB(200, 100, 255),
				Size = 6,
				Speed = 1.3,
			},
			{
				Name = "Mystic Vortex",
				Color = Color3.fromRGB(180, 80, 240),
				Size = 5.5,
				Speed = 1.5,
			},
			{
				Name = "Enchanted Aura",
				Color = Color3.fromRGB(210, 120, 255),
				Size = 5,
				Speed = 1.1,
			},
		},
	},
	Legendary = {
		Name = "Legendary",
		Rank = 5,
		Odds = 1000,                 -- 1 in 1000 (0.1%)
		CoinReward = 500,
		Color = Color3.fromRGB(255, 215, 0),
		TextColor = Color3.fromRGB(255, 240, 100),
		Auras = {
			{
				Name = "Golden Radiance",
				Color = Color3.fromRGB(255, 230, 50),
				Size = 7,
				Speed = 1.4,
			},
			{
				Name = "Solar Flare",
				Color = Color3.fromRGB(255, 200, 0),
				Size = 6.5,
				Speed = 1.6,
			},
			{
				Name = "Divine Light",
				Color = Color3.fromRGB(255, 250, 100),
				Size = 6,
				Speed = 1.2,
			},
		},
	},
	Mythical = {
		Name = "Mythical",
		Rank = 6,
		Odds = 10000,                -- 1 in 10000 (0.01%)
		CoinReward = 5000,
		Color = Color3.fromRGB(255, 0, 255),
		TextColor = Color3.fromRGB(255, 100, 255),
		Auras = {
			{
				Name = "Celestial Inferno",
				Color = Color3.fromRGB(255, 50, 255),
				Size = 8,
				Speed = 1.6,
			},
			{
				Name = "Cosmic Rupture",
				Color = Color3.fromRGB(200, 0, 255),
				Size = 7.5,
				Speed = 1.8,
			},
			{
				Name = "Dimensional Rift",
				Color = Color3.fromRGB(255, 0, 200),
				Size = 7,
				Speed = 1.4,
			},
		},
	},
}

-- Build weighted roll table for cumulative probability
local function BuildWeightedRollTable()
	local weightedTable = {}
	local totalWeight = 0

	-- Calculate total weight
	for _, tier in pairs(RarityTiers) do
		totalWeight += tier.Odds
	end

	-- Sort tiers by odds (ascending) for consistent ordering
	local sortedTiers = {}
	for _, tier in pairs(RarityTiers) do
		table.insert(sortedTiers, tier)
	end
	table.sort(sortedTiers, function(a, b)
		return a.Odds < b.Odds
	end)

	-- Build cumulative ranges
	local runningTotal = 0
	for _, tier in ipairs(sortedTiers) do
		local entry = {
			Name = tier.Name,
			Rank = tier.Rank,
			Odds = tier.Odds,
			CoinReward = tier.CoinReward,
			Color = tier.Color,
			TextColor = tier.TextColor,
			Auras = tier.Auras,
			Min = runningTotal,
			Max = runningTotal + tier.Odds,
		}
		table.insert(weightedTable, entry)
		runningTotal += tier.Odds
	end

	return weightedTable, totalWeight
end

local WeightedRollTable, TotalWeight = BuildWeightedRollTable()

-- ============================================================================
-- RNG ROLL LOGIC
-- ============================================================================
-- Returns a rolled tier with all associated data
local function RollTier()
	local random = Random.new()
	local rollValue = random:NextNumber(0, TotalWeight)

	for _, tier in ipairs(WeightedRollTable) do
		if rollValue >= tier.Min and rollValue < tier.Max then
			-- Randomly select one of the 3 auras for this tier
			local selectedAura = tier.Auras[random:NextInteger(1, #tier.Auras)]
			
			return {
				Name = tier.Name,
				Rank = tier.Rank,
				CoinReward = tier.CoinReward,
				Color = tier.Color,
				TextColor = tier.TextColor,
				AuraName = selectedAura.Name,
				AuraColor = selectedAura.Color,
				AuraSize = selectedAura.Size,
				AuraSpeed = selectedAura.Speed,
			}
		end
	end

	-- Fallback (should never reach here)
	return {
		Name = "Common",
		Rank = 1,
		CoinReward = 1,
		Color = Color3.fromRGB(200, 200, 200),
		TextColor = Color3.fromRGB(180, 180, 180),
		AuraName = "Plain Glow",
		AuraColor = Color3.fromRGB(200, 200, 200),
		AuraSize = 3,
		AuraSpeed = 1,
	}
end

-- ============================================================================
-- PLAYER DATA MANAGEMENT
-- ============================================================================
local function GetDefaultPlayerData()
	return {
		TotalRolls = 0,
		TotalCoins = 0,
		BestRoll = "None",
		BestRollRank = 0,
		LastRollTime = 0,
		RollHistory = {}, -- Track last 50 rolls
	}
end

local function GetPlayerData(player)
	local userId = player.UserId
	local data = GetDefaultPlayerData()

	local success, result = pcall(function()
		return PLAYER_DATA_STORE:GetAsync(userId)
	end)

	if success and type(result) == "table" then
		data.TotalRolls = result.TotalRolls or 0
		data.TotalCoins = result.TotalCoins or 0
		data.BestRoll = result.BestRoll or "None"
		data.BestRollRank = result.BestRollRank or 0
		data.RollHistory = result.RollHistory or {}
	else
		warn("Failed to load data for " .. player.Name .. " (ID: " .. userId .. ")")
	end

	return data
end

local function SavePlayerData(player, data)
	local userId = player.UserId
	local success, errorMessage = pcall(function()
		PLAYER_DATA_STORE:SetAsync(userId, data)
	end)

	if not success then
		warn("Failed to save data for " .. player.Name .. ": " .. tostring(errorMessage))
	end
end

local function UpdateBestRoll(currentBest, currentBestRank, rolledName, rolledRank)
	if rolledRank > currentBestRank then
		return rolledName, rolledRank
	end
	return currentBest, currentBestRank
end

-- ============================================================================
-- REMOTE EVENTS SETUP
-- ============================================================================
local function SetupRemotes()
	local remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "RNGRemotes"
	remoteFolder.Parent = game:GetService("ReplicatedStorage")

	local RollTriggered = Instance.new("RemoteEvent")
	RollTriggered.Name = "RollTriggered"
	RollTriggered.Parent = remoteFolder

	local UpdateClientUI = Instance.new("RemoteEvent")
	UpdateClientUI.Name = "UpdateClientUI"
	UpdateClientUI.Parent = remoteFolder

	return RollTriggered, UpdateClientUI
end

local RollTriggered, UpdateClientUI = SetupRemotes()

-- ============================================================================
-- ROLL HANDLER
-- ============================================================================
-- Validates roll request, processes RNG, awards coins, updates data
RollTriggered.OnServerEvent:Connect(function(player)
	if not player or not player.Parent then
		return
	end

	-- Load player data
	local playerData = GetPlayerData(player)

	-- Roll for rarity tier
	local rolledTier = RollTier()

	-- Update player stats
	playerData.TotalRolls += 1
	playerData.TotalCoins += rolledTier.CoinReward
	playerData.BestRoll, playerData.BestRollRank = UpdateBestRoll(
		playerData.BestRoll,
		playerData.BestRollRank,
		rolledTier.Name,
		rolledTier.Rank
	)

	-- Add to roll history (keep last 50)
	table.insert(playerData.RollHistory, 1, {
		RarityName = rolledTier.Name,
		Rank = rolledTier.Rank,
		Timestamp = os.time(),
	})
	if #playerData.RollHistory > 50 then
		table.remove(playerData.RollHistory)
	end

	-- Save data
	SavePlayerData(player, playerData)

	-- Send roll result and updated stats to client
	UpdateClientUI:FireClient(player, {
		RarityName = rolledTier.Name,
		Rank = rolledTier.Rank,
		AuraName = rolledTier.AuraName,
		AuraColor = rolledTier.AuraColor,
		AuraSize = rolledTier.AuraSize,
		AuraSpeed = rolledTier.AuraSpeed,
		Color = rolledTier.Color,
		TextColor = rolledTier.TextColor,
		CoinsEarned = rolledTier.CoinReward,
		TotalCoins = playerData.TotalCoins,
		TotalRolls = playerData.TotalRolls,
		BestRoll = playerData.BestRoll,
	})
end)

-- ============================================================================
-- PLAYER INITIALIZATION & CLEANUP
-- ============================================================================
Players.PlayerAdded:Connect(function(player)
	-- Initialize data on join
	local playerData = GetPlayerData(player)
	SavePlayerData(player, playerData)
end)

Players.PlayerRemoving:Connect(function(player)
	-- Final save before player leaves
	local playerData = GetPlayerData(player)
	SavePlayerData(player, playerData)
end)

print("✓ Sol's RNG System initialized successfully")
