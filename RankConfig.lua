--[[
	RankConfig.lua
	Location: ReplicatedStorage

	This is the ONLY file most users need to edit.
	Everything here is read by both the server (to do the ranking) and the
	client (to display messages in the "Check Rank" popup), so it lives in
	ReplicatedStorage rather than ServerScriptService.

	IMPORTANT: Do NOT put your Open Cloud API key in this file — it is
	visible to every client. The API key belongs in
	ServerScriptService/GamepassRankHandler.server.lua ONLY, or better,
	in a server-side Secret (see README "API key storage" section).
]]

local RankConfig = {}

-- Your group's numeric ID. Find it in your group's URL:
-- https://www.roblox.com/communities/GROUP_ID/your-group-name
RankConfig.GroupId = 0000000

-- Each entry maps a GamePassId -> the group RoleId it should grant.
-- RoleId (NOT rank number 1-255) is the internal role ID — get it from
-- the Open Cloud "List Group Roles" endpoint or the group's Configure
-- Roles page network request. See README for exact steps.
--
-- If a player owns more than one of these gamepasses, the handler grants
-- the HIGHEST matching role automatically (it does not rank down).
RankConfig.GamepassRanks = {
	[0000000001] = {
		RoleId = 00000001,
		Message = "You've been auto-ranked to VIP for owning the VIP gamepass!",
	},
	[0000000002] = {
		RoleId = 00000002,
		Message = "You've been auto-ranked to Supporter — thanks for the support!",
	},
	-- Add as many gamepass -> role pairs as you like:
	-- [gamepassId] = { RoleId = roleId, Message = "custom message" },
}

-- Shown in the "Check Rank" popup if the player doesn't own any ranked gamepass yet.
RankConfig.NoRankMessage = "You haven't unlocked an auto-rank yet. Grab a gamepass to get ranked instantly!"

-- Shown in the "Check Rank" popup header.
RankConfig.CheckRankTitle = "Your Group Rank"

-- Topbar button icon (rbxassetid://...). 0 = uses the built-in fallback glyph.
RankConfig.ButtonIcon = "rbxassetid://0"

return RankConfig
