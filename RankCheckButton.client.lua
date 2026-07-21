--[[
	RankCheckButton.client.lua
	Location: StarterPlayer/StarterPlayerScripts

	Roblox doesn't currently give experiences a first-party API to insert an
	icon directly into the real system topbar — that's a Studio-plugin-only
	feature. This script instead draws a small button docked just under the
	topbar (top-right), which is the standard approach every game using a
	"topbar button" actually uses. It opens a popup showing the player's
	current group role and which ranked gamepasses they own.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local RankConfig = require(ReplicatedStorage:WaitForChild("RankConfig"))
local remotesFolder = ReplicatedStorage:WaitForChild("GamepassRankRemotes")
local getRankInfo = remotesFolder:WaitForChild("GetRankInfo")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ---------- Build the button ----------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GamepassRankUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.Parent = playerGui

local button = Instance.new("ImageButton")
button.Name = "CheckRankButton"
button.AnchorPoint = Vector2.new(1, 0)
button.Position = UDim2.new(1, -8, 0, 8)
button.Size = UDim2.new(0, 36, 0, 36)
button.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
button.BorderSizePixel = 0
button.Image = RankConfig.ButtonIcon ~= "rbxassetid://0" and RankConfig.ButtonIcon or ""
button.AutoButtonColor = true
button.Parent = screenGui

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(1, 0)
buttonCorner.Parent = button

if RankConfig.ButtonIcon == "rbxassetid://0" then
	local fallbackLabel = Instance.new("TextLabel")
	fallbackLabel.BackgroundTransparency = 1
	fallbackLabel.Size = UDim2.fromScale(1, 1)
	fallbackLabel.Text = "R"
	fallbackLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	fallbackLabel.Font = Enum.Font.GothamBold
	fallbackLabel.TextScaled = true
	fallbackLabel.Parent = button
end

-- ---------- Build the popup ----------
local popup = Instance.new("Frame")
popup.Name = "RankPopup"
popup.AnchorPoint = Vector2.new(1, 0)
popup.Position = UDim2.new(1, -8, 0, 52)
popup.Size = UDim2.new(0, 260, 0, 0)
popup.AutomaticSize = Enum.AutomaticSize.Y
popup.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
popup.BorderSizePixel = 0
popup.Visible = false
popup.Parent = screenGui

local popupCorner = Instance.new("UICorner")
popupCorner.CornerRadius = UDim.new(0, 10)
popupCorner.Parent = popup

local popupPadding = Instance.new("UIPadding")
popupPadding.PaddingTop = UDim.new(0, 12)
popupPadding.PaddingBottom = UDim.new(0, 12)
popupPadding.PaddingLeft = UDim.new(0, 14)
popupPadding.PaddingRight = UDim.new(0, 14)
popupPadding.Parent = popup

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
layout.Parent = popup

local title = Instance.new("TextLabel")
title.Text = RankConfig.CheckRankTitle
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Size = UDim2.new(1, 0, 0, 20)
title.LayoutOrder = 1
title.Parent = popup

local roleLabel = Instance.new("TextLabel")
roleLabel.Text = "Loading..."
roleLabel.Font = Enum.Font.Gotham
roleLabel.TextSize = 14
roleLabel.TextColor3 = Color3.fromRGB(200, 200, 205)
roleLabel.BackgroundTransparency = 1
roleLabel.TextXAlignment = Enum.TextXAlignment.Left
roleLabel.TextWrapped = true
roleLabel.Size = UDim2.new(1, 0, 0, 0)
roleLabel.AutomaticSize = Enum.AutomaticSize.Y
roleLabel.LayoutOrder = 2
roleLabel.Parent = popup

local infoLabel = Instance.new("TextLabel")
infoLabel.Text = ""
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 13
infoLabel.TextColor3 = Color3.fromRGB(150, 220, 150)
infoLabel.BackgroundTransparency = 1
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextWrapped = true
infoLabel.Size = UDim2.new(1, 0, 0, 0)
infoLabel.AutomaticSize = Enum.AutomaticSize.Y
infoLabel.LayoutOrder = 3
infoLabel.Parent = popup

-- ---------- Behaviour ----------
local isOpen = false
local loadedOnce = false

local function refreshRankInfo()
	roleLabel.Text = "Loading..."
	infoLabel.Text = ""

	local ok, info = pcall(function()
		return getRankInfo:InvokeServer()
	end)

	if not ok or not info then
		roleLabel.Text = "Couldn't load your rank right now — try again in a moment."
		return
	end

	roleLabel.Text = string.format("Current role: %s", info.RoleName or "Guest")

	if info.OwnedGamepasses and #info.OwnedGamepasses > 0 then
		local lines = {}
		for _, entry in ipairs(info.OwnedGamepasses) do
			table.insert(lines, "• " .. (entry.Message or "Ranked gamepass owned"))
		end
		infoLabel.Text = table.concat(lines, "\n")
	else
		infoLabel.Text = RankConfig.NoRankMessage
	end
end

button.MouseButton1Click:Connect(function()
	isOpen = not isOpen
	popup.Visible = isOpen
	if isOpen then
		refreshRankInfo()
	end
end)
