# Gamepass Ranking System

Auto-ranks group members the instant they own a configured gamepass, using
Roblox's **Open Cloud** Groups API — no bot account, no cookie.

## What's included

| File | Where it goes | What it does |
|---|---|---|
| `ReplicatedStorage/RankConfig.lua` | `ReplicatedStorage` | The only file you need to edit day-to-day: group ID, gamepass→role mapping, messages. |
| `ServerScriptService/GamepassRankHandler.server.lua` | `ServerScriptService` | Detects ownership, calls Open Cloud, exposes the rank-check remote. |
| `StarterPlayerScripts/RankCheckButton.client.lua` | `StarterPlayer > StarterPlayerScripts` | Adds the "check my rank" button and popup. |

## Install (5–10 minutes)

1. **Enable HTTP requests.** Home > Game Settings > Security > turn on
   *"Allow HTTP Requests"*. Without this, every ranking call fails.
2. Drag the three files into the matching locations in Studio's Explorer
   (table above).
3. Open `RankConfig.lua` and set:
   - `GroupId` — your group's numeric ID from its URL.
   - `GamepassRanks` — one entry per gamepass, mapping to the **RoleId**
     (not the rank number 1–255) you want it to grant. See below for how
     to find RoleIds.
4. Get an **Open Cloud API key** with `group:write` and `group:read`
   scopes for your group at
   https://create.roblox.com/dashboard/credentials — scope it to your
   specific group, not "All groups."
5. Paste that key into `OPEN_CLOUD_API_KEY` at the top of
   `GamepassRankHandler.server.lua`.
6. Publish and test with an alt account that doesn't already hold a high
   role.

### Finding a RoleId

Call the Open Cloud "List Group Roles" endpoint once (Postman, curl, or
even a throwaway script) against
`GET https://apis.roblox.com/cloud/v2/groups/{groupId}/roles` with your
API key in the `x-api-key` header. The response lists every role with its
`id` — that's the RoleId to put in `RankConfig.lua`.

## Two things worth knowing before you rely on this

**1. This endpoint is still Beta and its request format can move.**
Roblox has changed the Groups Open Cloud API's request/response shape
before, and the docs still tag Update Group Membership as *Beta*. The
handler sends the standard Open Cloud resource-path body
(`{"role": "groups/<id>/roles/<id>"}`). If you get an HTTP 400 back (check
the Output window — `setGroupRole` logs the response body), open
[Roblox's current Groups API reference](https://create.roblox.com/docs/cloud/reference/features/groups),
look at "Update Group Membership," and adjust the `encodeRoleBody`
function to match. It's a couple of lines, not a rewrite.

**2. API-key permissions for group ranking have been inconsistent for some
developers.** Some report 401s even with correctly-scoped keys — this
tends to trace back to key scope (must be tied to the group, not your
account generally) or to the key's creator not having sufficient
permissions in the group themselves. If you hit a persistent 401/403 after
double-checking scope, that's a Roblox-side permissions quirk worth
searching the Developer Forum for, since it's changed a few times as this
API has matured.

Point 1 is why the handler isolates the request-body logic into one small
function — so a schema change is a one-function fix, not a rewrite.

## About the 16+ rank-center note

Roblox's evolving policy around age verification for in-experience group
management (manually promoting members via an in-game "rank center" NPC or
kiosk) is why an automated, Open-Cloud-driven flow like this is useful:
ranking happens server-side against your API key rather than through a
manual staff-operated in-game tool. If your group relies on a rank center
today, check Roblox's current Group Management / Trust & Safety
documentation for the specifics that apply to your group, since exact
requirements have been in flux.

## Customizing further

- **Rank someone down automatically** if they refund/lose a gamepass:
  add a periodic re-check loop (`task.spawn` + `task.wait`) that re-runs
  `getHighestQualifyingRole` for online players and ranks down if they no
  longer qualify. Not included by default so staff-assigned roles above
  the gamepass tiers are never touched accidentally.
- **Multiple currencies of rank** (e.g. Developer Products instead of
  Gamepasses): swap `MarketplaceService:UserOwnsGamePassAsync` for a
  DataStore-backed purchase record, since dev products don't have a
  built-in "ownership" concept.
