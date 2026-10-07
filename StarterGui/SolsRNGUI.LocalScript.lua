-- StarterGui/SolsRNGUI.LocalScript
-- Client-side UI framework for Sol's RNG with auto-roll toggle, cinematic pop-ups, and camera shake
-- Place this script in StarterGui as a LocalScript

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- ============================================================================
-- REMOTES SETUP
-- ============================================================================
local remotesFolder = ReplicatedStorage:WaitForChild("RNGRemotes")
local RollTriggered = remotesFolder:WaitForChild("RollTriggered")
local UpdateClientUI = remotesFolder:WaitForChild("UpdateClientUI")

-- ============================================================================
-- UI STATE MANAGEMENT
-- ============================================================================
local UIState = {
	AutoRollEnabled = false,
	IsRolling = false,
	CurrentCoins = 0,
	TotalRolls = 0,
	BestRoll = "None",
	RollCooldown = 0.5, -- seconds between rolls
	LastRollTime = 0,
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
local function GetTime()
	return tick()
end

local function CanRoll()
	return (GetTime() - UIState.LastRollTime) >= UIState.RollCooldown
end

local function TweenSize(instance, endSize, duration)
	local tweenInfo = TweenInfo.new(
		duration,
		Enum.EasingStyle.Cubic,
		Enum.EasingDirection.Out
	)
	local tween = game:GetService("TweenService"):Create(instance, tweenInfo, {
		Size = endSize,
	})
	tween:Play()
	return tween
end

local function TweenPosition(instance, endPosition, duration)
	local tweenInfo = TweenInfo.new(
		duration,
		Enum.EasingStyle.Cubic,
		Enum.EasingDirection.Out
	)
	local tween = game:GetService("TweenService"):Create(instance, tweenInfo, {
		Position = endPosition,
	})
	tween:Play()
	return tween
end

local function TweenTransparency(instance, endTransparency, duration)
	local tweenInfo = TweenInfo.new(
		duration,
		Enum.EasingStyle.Cubic,
		Enum.EasingDirection.In
	)
	local tween = game:GetService("TweenService"):Create(instance, tweenInfo, {
		TextTransparency = endTransparency,
		BackgroundTransparency = instance.BackgroundTransparency + (endTransparency - instance.TextTransparency),
	})
	tween:Play()
	return tween
end

local function TweenColor(instance, endColor, duration)
	local tweenInfo = TweenInfo.new(
		duration,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	local tween = game:GetService("TweenService"):Create(instance, tweenInfo, {
		TextColor3 = endColor,
	})
	tween:Play()
	return tween
end

-- ============================================================================
-- CAMERA SHAKE EFFECT
-- ============================================================================
local function CameraShake(intensity, duration, frequency)
	intensity = intensity or 0.5
	duration = duration or 0.5
	frequency = frequency or 10

	local startTime = GetTime()
	local originalCFrame = camera.CFrame

	while (GetTime() - startTime) < duration do
		local elapsed = GetTime() - startTime
		local progress = elapsed / duration
		
		-- Exponential decay for shake intensity
		local currentIntensity = intensity * (1 - progress)
		
		-- Sine wave oscillation for smooth shaking
		local shakeX = math.sin(elapsed * frequency * math.pi * 2) * currentIntensity
		local shakeY = math.cos(elapsed * frequency * math.pi * 1.5) * currentIntensity
		local shakeZ = math.sin(elapsed * frequency * math.pi) * currentIntensity

		camera.CFrame = originalCFrame * CFrame.new(shakeX, shakeY, shakeZ)
		
		RunService.RenderStepped:Wait()
	end

	camera.CFrame = originalCFrame
end

-- ============================================================================
-- MAIN UI SCREEN SETUP
-- ============================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SolsRNGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Main control panel (bottom-left)
local controlPanel = Instance.new("Frame")
controlPanel.Name = "ControlPanel"
controlPanel.Size = UDim2.new(0, 320, 0, 180)
controlPanel.Position = UDim2.new(0, 20, 1, -200)
controlPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
controlPanel.BorderSizePixel = 0
controlPanel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = controlPanel

local panelBorder = Instance.new("UIStroke")
panelBorder.Color = Color3.fromRGB(80, 100, 150)
panelBorder.Thickness = 1.5
panelBorder.Parent = controlPanel

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -10, 0, 30)
titleLabel.Position = UDim2.new(0, 5, 0, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Sol's RNG"
titleLabel.TextColor3 = Color3.fromRGB(100, 150, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 20
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = controlPanel

-- Coins display
local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "CoinsLabel"
coinsLabel.Size = UDim2.new(1, -10, 0, 25)
coinsLabel.Position = UDim2.new(0, 5, 0, 35)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text = "Coins: 0"
coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
coinsLabel.Font = Enum.Font.GothamSemibold
coinsLabel.TextSize = 14
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.Parent = controlPanel

-- Rolls display
local rollsLabel = Instance.new("TextLabel")
rollsLabel.Name = "RollsLabel"
rollsLabel.Size = UDim2.new(1, -10, 0, 25)
rollsLabel.Position = UDim2.new(0, 5, 0, 60)
rollsLabel.BackgroundTransparency = 1
rollsLabel.Text = "Rolls: 0"
rollsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
rollsLabel.Font = Enum.Font.Gotham
rollsLabel.TextSize = 14
rollsLabel.TextXAlignment = Enum.TextXAlignment.Left
rollsLabel.Parent = controlPanel

-- Auto-roll toggle button
local autoRollButton = Instance.new("TextButton")
autoRollButton.Name = "AutoRollButton"
autoRollButton.Size = UDim2.new(0, 140, 0, 35)
autoRollButton.Position = UDim2.new(0, 5, 0, 140)
autoRollButton.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
autoRollButton.Text = "AUTO ROLL: OFF"
autoRollButton.TextColor3 = Color3.fromRGB(255, 255, 255)
autoRollButton.Font = Enum.Font.GothamBold
autoRollButton.TextSize = 12
autoRollButton.Parent = controlPanel

local autoRollCorner = Instance.new("UICorner")
autoRollCorner.CornerRadius = UDim.new(0, 8)
autoRollCorner.Parent = autoRollButton

local autoRollStroke = Instance.new("UIStroke")
autoRollStroke.Color = Color3.fromRGB(80, 150, 255)
autoRollStroke.Thickness = 1
autoRollStroke.Parent = autoRollButton

-- Manual roll button
local rollButton = Instance.new("TextButton")
rollButton.Name = "RollButton"
rollButton.Size = UDim2.new(0, 140, 0, 35)
rollButton.Position = UDim2.new(0, 170, 0, 140)
rollButton.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
rollButton.Text = "ROLL"
rollButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rollButton.Font = Enum.Font.GothamBold
rollButton.TextSize = 14
rollButton.Parent = controlPanel

local rollCorner = Instance.new("UICorner")
rollCorner.CornerRadius = UDim.new(0, 8)
rollCorner.Parent = rollButton

local rollStroke = Instance.new("UIStroke")
rollStroke.Color = Color3.fromRGB(100, 230, 150)
rollStroke.Thickness = 1
rollStroke.Parent = rollButton

-- ============================================================================
-- RARITY POP-UP CREATION
-- ============================================================================
local function CreateRarityPopup(rarityData)
	local popupGui = Instance.new("ScreenGui")
	popupGui.Name = "RarityPopup_" .. rarityData.RarityName
	popupGui.ResetOnSpawn = false
	popupGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	popupGui.Parent = playerGui

	local isLegendaryOrMythical = rarityData.Rank >= 5

	-- Background overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.3
	overlay.BorderSizePixel = 0
	overlay.Parent = popupGui

	-- Main popup frame (centered)
	local popupFrame = Instance.new("Frame")
	popupFrame.Name = "PopupFrame"
	popupFrame.Size = UDim2.new(0, 500, 0, 350)
	popupFrame.Position = UDim2.new(0.5, -250, 0.5, -175)
	popupFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
	popupFrame.BorderSizePixel = 0
	popupFrame.Parent = popupGui

	local popupCorner = Instance.new("UICorner")
	popupCorner.CornerRadius = UDim.new(0, 16)
	popupCorner.Parent = popupFrame

	-- Gradient border effect
	local popupBorder = Instance.new("UIStroke")
	popupBorder.Color = rarityData.Color
	popupBorder.Thickness = 2.5
	popupBorder.Parent = popupFrame

	-- Rarity name (large and bold)
	local rarityNameLabel = Instance.new("TextLabel")
	rarityNameLabel.Name = "RarityName"
	rarityNameLabel.Size = UDim2.new(1, -40, 0, 80)
	rarityNameLabel.Position = UDim2.new(0, 20, 0, 20)
	rarityNameLabel.BackgroundTransparency = 1
	rarityNameLabel.Text = rarityData.RarityName:upper()
	rarityNameLabel.TextColor3 = rarityData.TextColor
	rarityNameLabel.Font = Enum.Font.GothamBold
	rarityNameLabel.TextSize = 48
	rarityNameLabel.TextXAlignment = Enum.TextXAlignment.Center
	rarityNameLabel.TextYAlignment = Enum.TextYAlignment.Center
	rarityNameLabel.Parent = popupFrame

	-- Aura name
	local auraLabel = Instance.new("TextLabel")
	auraLabel.Name = "AuraName"
	auraLabel.Size = UDim2.new(1, -40, 0, 40)
	auraLabel.Position = UDim2.new(0, 20, 0, 100)
	auraLabel.BackgroundTransparency = 1
	auraLabel.Text = "✨ " .. rarityData.AuraName .. " ✨"
	auraLabel.TextColor3 = rarityData.AuraColor
	auraLabel.Font = Enum.Font.GothamSemibold
	auraLabel.TextSize = 18
	auraLabel.TextXAlignment = Enum.TextXAlignment.Center
	auraLabel.Parent = popupFrame

	-- Coins earned display
	local coinsEarnedLabel = Instance.new("TextLabel")
	coinsEarnedLabel.Name = "CoinsEarned"
	coinsEarnedLabel.Size = UDim2.new(1, -40, 0, 35)
	coinsEarnedLabel.Position = UDim2.new(0, 20, 0, 150)
	coinsEarnedLabel.BackgroundTransparency = 1
	coinsEarnedLabel.Text = "+" .. tostring(rarityData.CoinsEarned) .. " Coins"
	coinsEarnedLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	coinsEarnedLabel.Font = Enum.Font.GothamBold
	coinsEarnedLabel.TextSize = 28
	coinsEarnedLabel.TextXAlignment = Enum.TextXAlignment.Center
	coinsEarnedLabel.Parent = popupFrame

	-- Stats section
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "Stats"
	statsFrame.Size = UDim2.new(1, -40, 0, 80)
	statsFrame.Position = UDim2.new(0, 20, 0, 200)
	statsFrame.BackgroundTransparency = 1
	statsFrame.Parent = popupFrame

	local totalRollsLabel = Instance.new("TextLabel")
	totalRollsLabel.Size = UDim2.new(0.5, 0, 0.5, 0)
	totalRollsLabel.Position = UDim2.new(0, 0, 0, 0)
	totalRollsLabel.BackgroundTransparency = 1
	totalRollsLabel.Text = "Total Rolls\n" .. tostring(rarityData.TotalRolls)
	totalRollsLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	totalRollsLabel.Font = Enum.Font.Gotham
	totalRollsLabel.TextSize = 14
	totalRollsLabel.TextXAlignment = Enum.TextXAlignment.Center
	totalRollsLabel.TextYAlignment = Enum.TextYAlignment.Center
	totalRollsLabel.Parent = statsFrame

	local bestRollLabel = Instance.new("TextLabel")
	bestRollLabel.Size = UDim2.new(0.5, 0, 0.5, 0)
	bestRollLabel.Position = UDim2.new(0.5, 0, 0, 0)
	bestRollLabel.BackgroundTransparency = 1
	bestRollLabel.Text = "Best Roll\n" .. tostring(rarityData.BestRoll)
	bestRollLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	bestRollLabel.Font = Enum.Font.Gotham
	bestRollLabel.TextSize = 14
	bestRollLabel.TextXAlignment = Enum.TextXAlignment.Center
	bestRollLabel.TextYAlignment = Enum.TextYAlignment.Center
	bestRollLabel.Parent = statsFrame

	local totalCoinsLabel = Instance.new("TextLabel")
	totalCoinsLabel.Size = UDim2.new(1, 0, 0.5, 0)
	totalCoinsLabel.Position = UDim2.new(0, 0, 0.5, 0)
	totalCoinsLabel.BackgroundTransparency = 1
	totalCoinsLabel.Text = "Total Coins: " .. tostring(rarityData.TotalCoins)
	totalCoinsLabel.TextColor3 = Color3.fromRGB(255, 230, 100)
	totalCoinsLabel.Font = Enum.Font.GothamSemibold
	totalCoinsLabel.TextSize = 14
	totalCoinsLabel.TextXAlignment = Enum.TextXAlignment.Center
	totalCoinsLabel.TextYAlignment = Enum.TextYAlignment.Center
	totalCoinsLabel.Parent = statsFrame

	-- LEGENDARY/MYTHICAL EFFECTS
	if isLegendaryOrMythical then
		-- Giant rarity text overlay (behind-the-scenes)
		local giantTextFrame = Instance.new("Frame")
		giantTextFrame.Name = "GiantText"
		giantTextFrame.Size = UDim2.new(2, 0, 2, 0)
		giantTextFrame.Position = UDim2.new(-0.5, 0, -0.5, 0)
		giantTextFrame.BackgroundTransparency = 1
		giantTextFrame.Parent = popupGui

		local giantLabel = Instance.new("TextLabel")
		giantLabel.Size = UDim2.new(1, 0, 1, 0)
		giantLabel.BackgroundTransparency = 1
		giantLabel.Text = rarityData.RarityName:upper()
		giantLabel.TextColor3 = rarityData.Color
		giantLabel.Font = Enum.Font.GothamBold
		giantLabel.TextSize = 180
		giantLabel.TextTransparency = 0.7
		giantLabel.TextXAlignment = Enum.TextXAlignment.Center
		giantLabel.TextYAlignment = Enum.TextYAlignment.Center
		giantLabel.Parent = giantTextFrame

		-- Animate giant text
		task.spawn(function()
			for i = 1, 3 do
				TweenSize(giantTextFrame, UDim2.new(2.5, 0, 2.5, 0), 0.5):Wait()
				TweenSize(giantTextFrame, UDim2.new(2, 0, 2, 0), 0.5):Wait()
			end
		end)

		-- Camera shake effect
		task.spawn(function()
			CameraShake(1.5, 0.8, 8)
		end)
	end

	-- Entrance animation
	popupFrame.Size = UDim2.new(0, 400, 0, 280)
	TweenSize(popupFrame, UDim2.new(0, 500, 0, 350), 0.4):Wait()

	-- Auto-close after 4 seconds
	task.wait(4)

	-- Exit animation
	TweenTransparency(popupFrame, 1, 0.6):Wait()
	popupGui:Destroy()
end

-- ============================================================================
-- PERFORM ROLL
-- ============================================================================
local function PerformRoll()
	if not CanRoll() then
		return
	end

	if UIState.IsRolling then
		return
	end

	UIState.IsRolling = true
	UIState.LastRollTime = GetTime()

	-- Fire server roll event
	RollTriggered:FireServer()
end

-- ============================================================================
-- AUTO-ROLL LOOP
-- ============================================================================
local autoRollCoroutine = nil

local function StartAutoRoll()
	if autoRollCoroutine then
		return
	end

	UIState.AutoRollEnabled = true
	autoRollButton.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
	autoRollButton.Text = "AUTO ROLL: ON"

	autoRollCoroutine = task.spawn(function()
		while UIState.AutoRollEnabled do
			PerformRoll()
			task.wait(UIState.RollCooldown + 0.1) -- Small buffer to allow UI to update
		end
	end)
end

local function StopAutoRoll()
	UIState.AutoRollEnabled = false
	autoRollButton.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
	autoRollButton.Text = "AUTO ROLL: OFF"

	if autoRollCoroutine then
		task.cancel(autoRollCoroutine)
		autoRollCoroutine = nil
	end
end

-- ============================================================================
-- BUTTON CLICK HANDLERS
-- ============================================================================
autoRollButton.MouseButton1Click:Connect(function()
	if UIState.AutoRollEnabled then
		StopAutoRoll()
	else
		StartAutoRoll()
	end
end)

rollButton.MouseButton1Click:Connect(function()
	PerformRoll()
end)

-- ============================================================================
-- SERVER RESULT HANDLER
-- ============================================================================
UpdateClientUI.OnClientEvent:Connect(function(data)
	if not data then
		return
	end

	-- Update UI state
	UIState.CurrentCoins = data.TotalCoins
	UIState.TotalRolls = data.TotalRolls
	UIState.BestRoll = data.BestRoll

	-- Update labels
	coinsLabel.Text = "Coins: " .. tostring(data.TotalCoins)
	rollsLabel.Text = "Rolls: " .. tostring(data.TotalRolls)

	-- Create cinematic popup
	CreateRarityPopup(data)

	-- Reset rolling flag
	UIState.IsRolling = false
end)

-- ============================================================================
-- INPUT HANDLING
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	-- Space bar to roll
	if input.KeyCode == Enum.KeyCode.Space then
		PerformRoll()
	end

	-- T to toggle auto-roll
	if input.KeyCode == Enum.KeyCode.T then
		if UIState.AutoRollEnabled then
			StopAutoRoll()
		else
			StartAutoRoll()
		end
	end
end)

-- ============================================================================
-- CLEANUP ON PLAYER LEAVING
-- ============================================================================
player.Exited:Connect(function()
	if autoRollCoroutine then
		task.cancel(autoRollCoroutine)
	end
	screenGui:Destroy()
end)

print("✓ Sol's RNG UI initialized successfully")
print("  - Press SPACE to roll")
print("  - Press T to toggle auto-roll")
print("  - Click buttons to interact")
