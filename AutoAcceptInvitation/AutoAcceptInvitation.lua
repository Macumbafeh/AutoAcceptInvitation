AutoAcceptInvitationSave = nil -- saved settings - defaults set up during ADDON_LOADED event

local eventFrame = CreateFrame("frame") -- anonymous frame to handle events

-- possible decline settings
local DECLINE_ALL    = 1
local DECLINE_OTHERS = 2
local DECLINE_NONE   = 3

----------------------------------------------------------------------------------------------------
-- handle loading and invitation events
----------------------------------------------------------------------------------------------------
-- accept or decline the invitation and close the popup window
local function HandleInvitation(accept)
	if accept then
		AcceptGroup()
	else
		DeclineGroup()
	end
	StaticPopup_Hide("PARTY_INVITE")
end

eventFrame:SetScript("OnEvent", function(self, event, name)
	if event == "PARTY_INVITE_REQUEST" then
		-- if declining everyone, handle it now
		if AutoAcceptInvitationSave.decline == DECLINE_ALL then
			HandleInvitation(false)
			return
		end
		-- check the accept/deny list
		if AutoAcceptInvitationSave.list[name] ~= nil then
			HandleInvitation(AutoAcceptInvitationSave.list[name])
			return
		end
		-- check if they are in the same guild
		if AutoAcceptInvitationSave.acceptGuild and IsInGuild() then
			for i=1,GetNumGuildMembers() do
				if name == GetGuildRosterInfo(i) then
					HandleInvitation(true)
					return
				end
			end
		end
		-- check if they are on the friends list
		if AutoAcceptInvitationSave.acceptFriends then
			for i=1,GetNumFriends() do
				if name == GetFriendInfo(i) then
					HandleInvitation(true)
					return
				end
			end
		end
		-- check if unknown people should be denied
		if AutoAcceptInvitationSave.decline == DECLINE_OTHERS then
			HandleInvitation(false)
		end
		return
	end

	-- this is a good time to update the guild and friend lists - it won't work if you try too soon
	if event == "UPDATE_PENDING_MAIL" then
		eventFrame:UnregisterEvent(event) -- only need to do it once
		GuildRoster() -- update the guild member list to know who's a member
		ShowFriends() -- update the friend list to know who's on it
		return
	end

	-- set up default settings if they don't exist already
	if event == "ADDON_LOADED" and name == "AutoAcceptInvitation" then
		eventFrame:UnregisterEvent(event)
		if AutoAcceptInvitationSave               == nil then AutoAcceptInvitationSave               = {}           end
		if AutoAcceptInvitationSave.acceptGuild   == nil then AutoAcceptInvitationSave.acceptGuild   = true         end
		if AutoAcceptInvitationSave.acceptFriends == nil then AutoAcceptInvitationSave.acceptFriends = true         end
		if AutoAcceptInvitationSave.decline       == nil then AutoAcceptInvitationSave.decline       = DECLINE_NONE end
		if AutoAcceptInvitationSave.list          == nil then AutoAcceptInvitationSave.list          = {}           end
		return
	end
end)
eventFrame:RegisterEvent("PARTY_INVITE_REQUEST") -- for handling an invitation
eventFrame:RegisterEvent("UPDATE_PENDING_MAIL")  -- temporary - load friend/guild list
eventFrame:RegisterEvent("ADDON_LOADED")         -- temporary - handle loading and fixing settings

----------------------------------------------------------------------------------------------------
-- slash command
----------------------------------------------------------------------------------------------------
_G.SLASH_AUTOACCEPTINVITATION1 = "/autoacceptinvitation"
_G.SLASH_AUTOACCEPTINVITATION2 = "/aai"
function SlashCmdList.AUTOACCEPTINVITATION(input)
	input = input and input:lower() or ""

	local command, value = input:match("(%S+)%s*(.*)")
	command = command or input

	-- /aai guild
	if command == "guild" then
		if value == "on" then
			AutoAcceptInvitationSave.acceptGuild = true
			DEFAULT_CHAT_FRAME:AddMessage("Automatically accepting from guild members is now enabled.")
		elseif value == "off" then
			AutoAcceptInvitationSave.acceptGuild = false
			DEFAULT_CHAT_FRAME:AddMessage("Automatically accepting from guild members is now disabled.")
		else
			DEFAULT_CHAT_FRAME:AddMessage('Syntax: /aai guild <"on"|"off">')
		end
		return
	end
	-- /aai friends
	if command:match("^friend[s]*") then
		if value == "on" then
			AutoAcceptInvitationSave.acceptFriends = true
			DEFAULT_CHAT_FRAME:AddMessage("Automatically accepting from friends is now enabled.")
		elseif value == "off" then
			AutoAcceptInvitationSave.acceptFriends = false
			DEFAULT_CHAT_FRAME:AddMessage("Automatically accepting from friends is now disabled.")
		else
			DEFAULT_CHAT_FRAME:AddMessage('Syntax: /aai friends <"on"|"off">')
		end
		return
	end
	-- /aai decline
	if command == "decline" then
		if value == "on" or value == "all" then
			AutoAcceptInvitationSave.decline = DECLINE_ALL
			DEFAULT_CHAT_FRAME:AddMessage("You will now decline all invitations.")
		elseif value == "off" or value == "none" then
			AutoAcceptInvitationSave.decline = DECLINE_NONE 			DEFAULT_CHAT_FRAME:AddMessage("You will not decline invitations from unknown people.")
		elseif value == "others" then
			AutoAcceptInvitationSave.decline = DECLINE_OTHERS
			DEFAULT_CHAT_FRAME:AddMessage("You will decline invitations from people not on the allowed lists.")
		else
			DEFAULT_CHAT_FRAME:AddMessage('Syntax: /aai decline <"all"|"others"|"none">')
		end
		return
	end

	if value then
		-- put the name in proper case
		value = value:gsub("(%a)(%w*)", function(first,rest) return first:upper()..rest:lower() end)
		-- /aai accept
		if command == "accept" or command == "allow" then
			if AutoAcceptInvitationSave.list[value] == true then
				DEFAULT_CHAT_FRAME:AddMessage(value .. " is already on the acceptance list.")
			else
				AutoAcceptInvitationSave.list[value] = true
				DEFAULT_CHAT_FRAME:AddMessage(value .. " has been added to the acceptance list.")
			end
			return
		end
		-- /aai deny
		if command == "deny" then
			if AutoAcceptInvitationSave.list[value] == false then
				DEFAULT_CHAT_FRAME:AddMessage(value .. " is already on the deny list.")
			else
				AutoAcceptInvitationSave.list[value] = false
				DEFAULT_CHAT_FRAME:AddMessage(value .. " has been added to the deny list.")
			end
			return
		end
		-- /aai remove
		if command == "remove" then
			if AutoAcceptInvitationSave.list[value] ~= nil then
				AutoAcceptInvitationSave.list[value] = nil
				DEFAULT_CHAT_FRAME:AddMessage(value .. " has been removed.")
			else
				DEFAULT_CHAT_FRAME:AddMessage(value .. " is not on the accept or deny list.")
			end
			return
		end
	end

	-- bad or no command, so showing the syntax and option settings
	DEFAULT_CHAT_FRAME:AddMessage('AutoAcceptInvitation commands:', 1, 1, 0)
	DEFAULT_CHAT_FRAME:AddMessage('/aai guild <"on"|"off">')
	DEFAULT_CHAT_FRAME:AddMessage('/aai friends <"on"|"off">')
	DEFAULT_CHAT_FRAME:AddMessage('/aai <"accept"|"deny"|"remove"> <name>')
	DEFAULT_CHAT_FRAME:AddMessage('/aai decline <"all"|"others"|"none">')

	if next(AutoAcceptInvitationSave.list) ~= nil then
		local accept = {}
		local deny = {}
		for name,value in pairs(AutoAcceptInvitationSave.list) do
			table.insert(value and accept or deny, name)
		end
		DEFAULT_CHAT_FRAME:AddMessage(" ")
		if next(accept) ~= nil then
			DEFAULT_CHAT_FRAME:AddMessage("Accept list: " .. table.concat(accept, ", "), 0, 1, 0)
		end
		if next(deny) ~= nil then
			DEFAULT_CHAT_FRAME:AddMessage("Deny list: " .. table.concat(deny, ", "), 1, 0, 0)
		end
	end

	local ag = AutoAcceptInvitationSave.acceptGuild
	local af = AutoAcceptInvitationSave.acceptFriends
	DEFAULT_CHAT_FRAME:AddMessage("Accepting from guild: " .. (ag and "on" or "off"), ag and 0 or 1, ag and 1 or 0, 0)
	DEFAULT_CHAT_FRAME:AddMessage("Accepting from friends: " .. (af and "on" or "off"), af and 0 or 1, af and 1 or 0, 0)

	if AutoAcceptInvitationSave.decline == DECLINE_ALL then
		DEFAULT_CHAT_FRAME:AddMessage("You will currently decline ALL group invitations.", 1, 0, 0)
	elseif AutoAcceptInvitationSave.decline == DECLINE_OTHERS then
		DEFAULT_CHAT_FRAME:AddMessage("You will decline invitations from anyone not on the allow lists.", 1, 0, 0)
	end
end
