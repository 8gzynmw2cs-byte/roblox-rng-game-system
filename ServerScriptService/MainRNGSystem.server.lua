-- ServerScriptService/MainRNGSystem.server.lua
-- Updated: Harder Sol's RNG odds, 3-second server cooldown, aura visuals, and sound-ready roll events
-- Place in ServerScriptService

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PLAYER_DATA_STORE = DataStoreService:GetDataStore("SolsRNGPlayerData_v5")

local COOLDOWN_SECONDS = 3
local playerCooldowns = {}

local function CanPlayerRoll(player)
	local userId = player.UserId
	local currentTime = tick()

	if not playerCooldowns[userId] then
		playerCooldowns[userId] = 0
	end

	if (currentTime - playerCooldowns[userId]) >= COOLDOWN_SECONDS then
		playerCooldowns[userId] = currentTime
		return true, 0
	else
		local remaining = COOLDOWN_SECONDS - (currentTime - playerCooldowns[userId])
		return false, remaining
	end
end

local RarityTiers = {
	Common = {
		Name = "Common",
		Rank = 1,
		Odds = 2,
		CoinReward = 1,
		Color = Color3.fromRGB(200, 200, 200),
		TextColor = Color3.fromRGB(180, 180, 180),
		AuraFolder = "CommonAuras",
		Auras = {
			{ Name = "Plain Glow", Color = Color3.fromRGB(200, 200, 200), Size = 3, Speed = 1.0 },
			{ Name = "Dim Pulse", Color = Color3.fromRGB(150, 150, 150), Size = 2.5, Speed = 0.8 },
			{ Name = "Gray Shimmer", Color = Color3.fromRGB(170, 170, 170), Size = 2.0, Speed = 1.2 },
		},
	},
	Uncommon = {
		Name = "Uncommon",
		Rank = 2,
		Odds = 5,
		CoinReward = 5,
		Color = Color3.fromRGB(100, 200, 100),
		TextColor = Color3.fromRGB(80, 220, 80),
		AuraFolder = "UncommonAuras",
		Auras = {
			{ Name = "Green Radiance", Color = Color3.fromRGB(100, 255, 100), Size = 4.0, Speed = 1.1 },
			{ Name = "Mint Aura", Color = Color3.fromRGB(120, 240, 140), Size = 3.5, Speed = 1.3 },
			{ Name = "Emerald Pulse", Color = Color3.fromRGB(90, 210, 120), Size = 3.0, Speed = 0.9 },
		},
	},
	Rare = {
		Name = "Rare",
		Rank = 3,
		Odds = 50,
		CoinReward = 50,
		Color = Color3.fromRGB(100, 160, 255),
		TextColor = Color3.fromRGB(120, 180, 255),
		AuraFolder = "RareAuras",
		Auras = {
			{ Name = "Azure Storm", Color = Color3.fromRGB(100, 180, 255), Size = 5.0, Speed = 1.2 },
			{ Name = "Sapphire Glow", Color = Color3.fromRGB(80, 150, 240), Size = 4.5, Speed = 1.4 },
			{ Name = "Crystalline Shimmer", Color = Color3.fromRGB(110, 170, 255), Size = 4.0, Speed = 1.0 },
		},
	},
	Epic = {
		Name = "Epic",
		Rank = 4,
		Odds = 350,
		CoinReward = 200,
		Color = Color3.fromRGB(180, 100, 255),
		TextColor = Color3.fromRGB(200, 120, 255),
		AuraFolder = "EpicAuras",
		Auras = {
			{ Name = "Amethyst Flame", Color = Color3.fromRGB(200, 100, 255), Size = 6.0, Speed = 1.3 },
			{ Name = "Mystic Vortex", Color = Color3.fromRGB(180, 80, 240), Size = 5.5, Speed = 1.5 },
			{ Name = "Enchanted Aura", Color = Color3.fromRGB(210, 120, 255), Size = 5.0, Speed = 1.1 },
		},
	},
	Legendary = {
		Name = "Legendary",
		Rank = 5,
		Odds = 2500,
		CoinReward = 1000,
		Color = Color3.fromRGB(255, 215, 0),
		TextColor = Color3.fromRGB(255, 240, 100),
		AuraFolder = "LegendaryAuras",
		Auras = {
			{ Name = "Golden Radiance", Color = Color3.fromRGB(255, 230, 50), Size = 7.0, Speed = 1.4 },
			{ Name = "Solar Flare", Color = Color3.fromRGB(255, 200, 0), Size = 6.5, Speed = 1.6 },
			{ Name = "Divine Light", Color = Color3.fromRGB(255, 250, 100), Size = 6.0, Speed = 1.2 },
		},
	},
	Mythical = {
		Name = "Mythical",
		Rank = 6,
		Odds = 50000,
		CoinReward = 5000,
		Color = Color3.fromRGB(255, 0, 255),
		TextColor = Color3.fromRGB(255, 100, 255),
		AuraFolder = "MythicalAuras",
		Auras = {
			{ Name = "Celestial Inferno", Color = Color3.fromRGB(255, 50, 255), Size = 8.0, Speed = 1.6 },
			{ Name = "Cosmic Rupture", Color = Color3.fromRGB(200, 0, 255), Size = 7.5, Speed = 1.8 },
			{ Name = "Dimensional Rift", Color = Color3.fromRGB(255, 0, 200), Size = 7.0, Speed = 1.4 },
		},
	},
}

local function BuildWeightedRollTable()
	local weightedTable = {}
	local totalWeight = 0
	local sortedTiers = {}

	for _, tier in pairs(RarityTiers) do
		table.insert(sortedTiers, tier)
		totalWeight += tier.Odds
	end

	table.sort(sortedTiers, function(a, b)
		return a.Odds < b.Odds
	end)

	local runningTotal = 0
	for _, tier in ipairs(sortedTiers) do
		local entry = {
			Name = tier.Name,
			Rank = tier.Rank,
			Odds = tier.Odds,
			CoinReward = tier.CoinReward,
			Color = tier.Color,
			TextColor = tier.TextColor,
			AuraFolder = tier.AuraFolder,
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

local function RollTier()
	local random = Random.new()
	local value = random:NextNumber(0, TotalWeight)

	for _, tier in ipairs(WeightedRollTable) do
		if value >= tier.Min and value < tier.Max then
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
				AuraFolder = tier.AuraFolder,
				AuraIndex = (function()
					for i, aura in ipairs(tier.Auras) do
						if aura.Name == selectedAura.Name then
							return i
						end
					end
					return 1
				end)(),
			}
		end
	end

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
		AuraFolder = "CommonAuras",
		AuraIndex = 1,
	}
end

local function GetDefaultPlayerData()
	return {
		TotalRolls = 0,
		TotalCoins = 0,
		BestRoll = "None",
		BestRollRank = 0,
		ActiveAuraFolder = "CommonAuras",
		ActiveAuraIndex = 1,
		RollHistory = {},
	}
end

local function GetPlayerData(player)
	local data = GetDefaultPlayerData()
	local success, result = pcall(function()
		return PLAYER_DATA_STORE:GetAsync(player.UserId)
	end)

	if success and type(result) == "table" then
		data.TotalRolls = result.TotalRolls or 0
		data.TotalCoins = result.TotalCoins or 0
		data.BestRoll = result.BestRoll or "None"
		data.BestRollRank = result.BestRollRank or 0
		data.ActiveAuraFolder = result.ActiveAuraFolder or "CommonAuras"
		data.ActiveAuraIndex = result.ActiveAuraIndex or 1
		data.RollHistory = result.RollHistory or {}
	end

	return data
end

local function SavePlayerData(player, data)
	local success, errorMessage = pcall(function()
		PLAYER_DATA_STORE:SetAsync(player.UserId, data)
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

local function EquipAuraToCharacter(player, auraFolderName, auraIndex)
	if not player or not player.Character then
		return
	end

	local character = player.Character
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local oldAura = root:FindFirstChild("ActiveAura")
	if oldAura then
		oldAura:Destroy()
	end

	local auraRoot = ReplicatedStorage:FindFirstChild("Auras")
	if not auraRoot then
		warn("Missing ReplicatedStorage/Auras folder")
		return
	end

	local rarityFolder = auraRoot:FindFirstChild(auraFolderName)
	if not rarityFolder then
		warn("Aura folder missing: " .. auraFolderName)
		return
	end

	local auraVariant = rarityFolder:FindFirstChild("Aura" .. tostring(auraIndex))
	if not auraVariant then
		warn("Aura variant missing: Aura" .. tostring(auraIndex))
		return
	end

	local clone = auraVariant:Clone()
	clone.Name = "ActiveAura"
	clone.Parent = root
end

local remotesFolder = ReplicatedStorage:FindFirstChild("RNGRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "RNGRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local RollTriggered = remotesFolder:FindFirstChild("RollTriggered")
if not RollTriggered then
	RollTriggered = Instance.new("RemoteEvent")
	RollTriggered.Name = "RollTriggered"
	RollTriggered.Parent = remotesFolder
end

local UpdateClientUI = remotesFolder:FindFirstChild("UpdateClientUI")
if not UpdateClientUI then
	UpdateClientUI = Instance.new("RemoteEvent")
	UpdateClientUI.Name = "UpdateClientUI"
	UpdateClientUI.Parent = remotesFolder
end

local UpdateCooldown = remotesFolder:FindFirstChild("UpdateCooldown")
if not UpdateCooldown then
	UpdateCooldown = Instance.new("RemoteEvent")
	UpdateCooldown.Name = "UpdateCooldown"
	UpdateCooldown.Parent = remotesFolder
end

local PlaySoundEffect = remotesFolder:FindFirstChild("PlaySoundEffect")
if not PlaySoundEffect then
	PlaySoundEffect = Instance.new("RemoteEvent")
	PlaySoundEffect.Name = "PlaySoundEffect"
	PlaySoundEffect.Parent = remotesFolder
end

RollTriggered.OnServerEvent:Connect(function(player)
	if not player or not player.Parent then
		return
	end

	local canRoll, remaining = CanPlayerRoll(player)
	if not canRoll then
		UpdateCooldown:FireClient(player, remaining)
		return
	end

	UpdateCooldown:FireClient(player, 0)

	local playerData = GetPlayerData(player)
	local rolledTier = RollTier()

	playerData.TotalRolls += 1
	playerData.TotalCoins += rolledTier.CoinReward
	playerData.BestRoll, playerData.BestRollRank = UpdateBestRoll(
		playerData.BestRoll,
		playerData.BestRollRank,
		rolledTier.Name,
		rolledTier.Rank
	)
	playerData.ActiveAuraFolder = rolledTier.AuraFolder
	playerData.ActiveAuraIndex = rolledTier.AuraIndex

	table.insert(playerData.RollHistory, 1, {
		RarityName = rolledTier.Name,
		Rank = rolledTier.Rank,
		Timestamp = os.time(),
	})
	if #playerData.RollHistory > 50 then
		table.remove(playerData.RollHistory)
	end

	SavePlayerData(player, playerData)
	EquipAuraToCharacter(player, rolledTier.AuraFolder, rolledTier.AuraIndex)

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

	PlaySoundEffect:FireClient(player, {
		RarityName = rolledTier.Name,
		Rank = rolledTier.Rank,
		CoinsEarned = rolledTier.CoinReward,
	})
end)

Players.PlayerAdded:Connect(function(player)
	local data = GetPlayerData(player)
	SavePlayerData(player, data)

	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)
		EquipAuraToCharacter(player, data.ActiveAuraFolder, data.ActiveAuraIndex)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local data = GetPlayerData(player)
	SavePlayerData(player, data)
	playerCooldowns[player.UserId] = nil
end)

print("✓ Sol's RNG Server initialized")
print("✓ Odds updated to harder Sol-style values")
print("✓ 3-second cooldown enforced")
print("✓ Character aura cloning enabled")
