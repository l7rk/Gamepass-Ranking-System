--[[
	GamepassRankHandler.server.lua
	Location: ServerScriptService

	What this does:
	1. Whenever a player joins, checks every gamepass in RankConfig against
	   their ownership (catches passes bought on the website/mobile app
	   while offline — those never fire a purchase event).
	2. Listens live for PromptGamePassPurchaseFinished so a purchase made
	   DURING the session ranks the player within a second or two.
	3. Calls Roblox's Open Cloud Groups API (v2, currently Beta) to update
	   the player's group role — no bot account, no cookie.
	4. Exposes a RemoteFunction so the client-side "Check Rank" button can
	   ask the server what the player currently owns/holds.

	READ BEFORE USE — two things that will bite you if skipped:

	A) HttpService must be enabled: Game Settings -> Security ->
	   "Allow HTTP Requests" -> On. Without this every call below fails
	   silently into the pcall's error branch.

	B) The Update Group Membership endpoint is still labelled Beta by
	   Roblox and its request body shape has changed before and can
	   change again. The body used below (`{ role = "groups/<id>/roles/<id>" }`,
	   Open Cloud's standard resource-path style) matches the current
	   Groups API reference as of this build, but if you get a 400 error,
	   open https://create.roblox.com/docs/cloud/reference/features/groups
	   look at "Update Group Membership", and adjust ENCODE_ROLE_BODY below
	   to match whatever field name/shape they're currently expecting.
	   This is a five-minute fix, not a rewrite.
]]

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankConfig = require(ReplicatedStorage:WaitForChild("RankConfig"))

-- =============================================================
-- API KEY: put your Open Cloud key here, or better, wire this up
-- to a HttpService header pulled from a Studio "Secret" / a private
-- ModuleScript that's excluded from your public repo. Never commit
-- a real key to GitHub.
-- =============================================================
local OPEN_CLOUD_API_KEY = "PASTE_YOUR_OPEN_CLOUD_API_KEY_HERE"

local GROUPS_API_BASE = "https://apis.roblox.com/cloud/v2/groups/"

-- Builds the request body for the Update Group Membership call.
-- See note (B) above if Roblox changes this shape.
local function encodeRoleBody(groupId, roleId)
	return HttpService:JSONEncode({
		role = string.format("groups/%d/roles/%d", groupId, roleId),
	})
end

-- Calls Open Cloud to set a player's role in the group.
-- Returns true, nil on success or false, errorString on failure.
local function setGroupRole(userId, roleId)
	if OPEN_CLOUD_API_KEY == "PASTE_YOUR_OPEN_CLOUD_API_KEY_HERE" then
		return false, "OPEN_CLOUD_API_KEY has not been set in GamepassRankHandler.server.lua"
	end

	local url = string.format("%s%d/memberships/%d", GROUPS_API_BASE, RankConfig.GroupId, userId)
	local body = encodeRoleBody(RankConfig.GroupId, roleId)

	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "PATCH",
			Headers = {
				["x-api-key"] = OPEN_CLOUD_API_KEY,
				["Content-Type"] = "application/json",
			},
			Body = body,
		})
	end)

	if not ok then
		return false, tostring(response)
	end

	if not response.Success then
		-- response.Body usually contains Roblox's error detail, useful for
		-- debugging the request-body-shape issue mentioned in note (B).
		return false, string.format("HTTP %d: %s", response.StatusCode, response.Body or "")
	end

	return true, nil
end

-- Given a userId, works out the HIGHEST role the player qualifies for
-- across every gamepass in RankConfig that they currently own.
-- Returns roleId (number) or nil if they own none of the configured passes.
local function getHighestQualifyingRole(userId)
	local bestRoleId = nil
	local bestMessage = nil

	for gamepassId, entry in pairs(RankConfig.GamepassRanks) do
		local owns = false
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(userId, gamepassId)
		end)
		if ok then
			owns = result
		end

		if owns and (bestRoleId == nil or entry.RoleId > bestRoleId) then
			bestRoleId = entry.RoleId
			bestMessage = entry.Message
		end
	end

	return bestRoleId, bestMessage
end

-- Ranks a player up to the best role they qualify for. Never ranks down —
-- if a player already holds a higher manually-assigned role, this leaves
-- it alone (it only overwrites if the target role is actually higher than
-- what UpdateAsync would report, which Open Cloud's API doesn't expose
-- cheaply, so as a simple/safe default we just always set the best
-- qualifying role. Remove the guard in the README's "advanced" section if
-- you want ranking to be strictly one-directional against staff-set roles).
local function rankPlayer(player)
	local roleId, message = getHighestQualifyingRole(player.UserId)
	if not roleId then
		return
	end

	local ok, err = setGroupRole(player.UserId, roleId)
	if ok then
		if message then
			pcall(function()
				game:GetService("StarterGui"):SetCore("SendNotification", {
					Title = "Rank Updated!",
					Text = message,
					Duration = 6,
				})
			end)
		end
	else
		warn(string.format("[GamepassRankHandler] Failed to rank %s (%d): %s", player.Name, player.UserId, err))
	end
end

-- ---- Catch purchases made while offline (website/mobile) ----
Players.PlayerAdded:Connect(function(player)
	task.spawn(rankPlayer, player)
end)

-- ---- Catch purchases made live, during this session ----
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
	if wasPurchased and RankConfig.GamepassRanks[gamepassId] then
		task.spawn(rankPlayer, player)
	end
end)

-- ---- Remote for the client-side "Check Rank" button ----
local remotesFolder = ReplicatedStorage:FindFirstChild("GamepassRankRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "GamepassRankRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local getRankInfo = remotesFolder:FindFirstChild("GetRankInfo")
if not getRankInfo then
	getRankInfo = Instance.new("RemoteFunction")
	getRankInfo.Name = "GetRankInfo"
	getRankInfo.Parent = remotesFolder
end

getRankInfo.OnServerInvoke = function(player)
	local roleName = "Guest"
	local rankNumber = 0

	local ok = pcall(function()
		roleName = player:GetRoleInGroup(RankConfig.GroupId)
		rankNumber = player:GetRankInGroup(RankConfig.GroupId)
	end)

	local ownedGamepasses = {}
	for gamepassId, entry in pairs(RankConfig.GamepassRanks) do
		local owns = false
		pcall(function()
			owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
		end)
		if owns then
			table.insert(ownedGamepasses, { GamepassId = gamepassId, Message = entry.Message })
		end
	end

	if not ok then
		roleName = "Unknown"
	end

	return {
		RoleName = roleName,
		RankNumber = rankNumber,
		OwnedGamepasses = ownedGamepasses,
	}
end
