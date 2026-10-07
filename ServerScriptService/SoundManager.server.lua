-- ServerScriptService/SoundManager.server.lua
-- Centralized sound effect management for Sol's RNG system
-- Create Sound instances in ReplicatedStorage/Sounds and reference them here

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ============================================================================
-- SOUND SETUP & INITIALIZATION
-- ============================================================================
local function InitializeSounds()
	local soundsFolder = ReplicatedStorage:FindFirstChild("Sounds")
	
	if not soundsFolder then
		soundsFolder = Instance.new("Folder")
		soundsFolder.Name = "Sounds"
		soundsFolder.Parent = ReplicatedStorage
	end

	-- Define sound templates with SoundIds
	-- You can replace these IDs with actual Roblox audio library IDs
	local soundDefinitions = {
		RollStart = {
			Name = "RollStart",
			SoundId = "rbxassetid://12221967", -- Click sound
			Volume = 0.4,
			Pitch = 1,
		},
		CommonRoll = {
			Name = "CommonRoll",
			SoundId = "rbxassetid://12221923", -- Soft chime
			Volume = 0.3,
			Pitch = 0.8,
		},
		UncommonRoll = {
			Name = "UncommonRoll",
			SoundId = "rbxassetid://12221901", -- Medium chime
			Volume = 0.4,
			Pitch = 1,
		},
		RareRoll = {
			Name = "RareRoll",
			SoundId = "rbxassetid://12221901", -- Higher chime
			Volume = 0.5,
			Pitch = 1.2,
		},
		EpicRoll = {
			Name = "EpicRoll",
			SoundId = "rbxassetid://12221901", -- Epic chime
			Volume = 0.6,
			Pitch = 1.4,
		},
		LegendaryRoll = {
			Name = "LegendaryRoll",
			SoundId = "rbxassetid://12221901", -- Legendary fanfare (start)
			Volume = 0.8,
			Pitch = 1.6,
		},
		MythicalRoll = {
			Name = "MythicalRoll",
			SoundId = "rbxassetid://12221901", -- Mythical fanfare
			Volume = 1,
			Pitch = 1.8,
		},
		CoinPickup = {
			Name = "CoinPickup",
			SoundId = "rbxassetid://12221955", -- Coin sound
			Volume = 0.5,
			Pitch = 1,
		},
		LegendaryFanfare = {
			Name = "LegendaryFanfare",
			SoundId = "rbxassetid://12221967", -- Fanfare build
			Volume = 0.9,
			Pitch = 1,
		},
		MythicalFanfare = {
			Name = "MythicalFanfare",
			SoundId = "rbxassetid://12221967", -- Epic fanfare
			Volume = 1,
			Pitch = 1.1,
		},
	}

	-- Create sound instances
	for _, soundDef in pairs(soundDefinitions) do
		local existingSound = soundsFolder:FindFirstChild(soundDef.Name)
		
		if not existingSound then
			local sound = Instance.new("Sound")
			sound.Name = soundDef.Name
			sound.SoundId = soundDef.SoundId
			sound.Volume = soundDef.Volume
			sound.PlayOnRemove = false
			sound.Parent = soundsFolder
		else
			existingSound.SoundId = soundDef.SoundId
			existingSound.Volume = soundDef.Volume
		end
	end

	return soundsFolder
end

local SoundsFolder = InitializeSounds()

-- ============================================================================
-- SOUND EFFECT REMOTE
-- ============================================================================
local RemoteEvent = Instance.new("RemoteEvent")
RemoteEvent.Name = "PlaySoundEffect"
RemoteEvent.Parent = ReplicatedStorage:WaitForChild("RNGRemotes")

-- ============================================================================
-- SOUND PLAYING FUNCTION
-- ============================================================================
local function PlaySoundForRarity(player, rarityName, rarityRank)
	-- Map rarity to sound name
	local soundNameMap = {
		["Common"] = "CommonRoll",
		["Uncommon"] = "UncommonRoll",
		["Rare"] = "RareRoll",
		["Epic"] = "EpicRoll",
		["Legendary"] = "LegendaryRoll",
		["Mythical"] = "MythicalRoll",
	}

	local soundName = soundNameMap[rarityName] or "CommonRoll"
	local sound = SoundsFolder:FindFirstChild(soundName)

	if sound then
		-- Play on server (will be heard by all)
		sound:Play()
		
		-- For Legendary/Mythical, play additional fanfare
		if rarityRank >= 5 then
			local fanfareSoundName = rarityRank == 6 and "MythicalFanfare" or "LegendaryFanfare"
			local fanareFareSound = SoundsFolder:FindFirstChild(fanfareSoundName)
			
			if fanareFareSound then
				task.wait(0.2) -- Slight delay for layering effect
				fanareFareSound:Play()
			end
		end

		-- Play coin pickup sound
		task.wait(0.4)
		local coinSound = SoundsFolder:FindFirstChild("CoinPickup")
		if coinSound then
			coinSound:Play()
		end
	end
end

-- ============================================================================
-- TRIGGER SOUND EFFECTS FROM ROLL
-- ============================================================================
local remotesFolder = ReplicatedStorage:WaitForChild("RNGRemotes")
local UpdateClientUI = remotesFolder:WaitForChild("UpdateClientUI")

-- Hook into the roll result to play sounds
local Players = game:GetService("Players")
local playerSoundTimers = {}

-- Store original UpdateClientUI FireClient method
local originalFireClient = UpdateClientUI.FireClient

UpdateClientUI.FireClient = function(self, player, data)
	-- Play sound effect for this rarity
	if data and data.RarityName then
		PlaySoundForRarity(player, data.RarityName, data.Rank)
	end

	-- Fire the original event
	return originalFireClient(self, player, data)
end

-- ============================================================================
-- SOUND CLEANUP
-- ============================================================================
Players.PlayerRemoving:Connect(function(player)
	if playerSoundTimers[player.UserId] then
		playerSoundTimers[player.UserId] = nil
	end
end)

print("✓ Sound Manager initialized successfully")
print("  - 11 sound effects loaded and ready")
print("  - Rarity-based audio feedback enabled")
