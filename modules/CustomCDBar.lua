local AceOO = AceLibrary("AceOO-2.0")

IceCustomCDBar = AceOO.Class(IceUnitBar)


local validBuffTimers = {"none", "seconds", "minutes:seconds", "minutes"}

IceCustomCDBar.prototype.cooldownDuration = 0
IceCustomCDBar.prototype.cooldownEndTime = 0



-- Constructor --
function IceCustomCDBar.prototype:init()
	IceCustomCDBar.super.prototype.init(self, "MyCustomCDBar", "player")
end

-- 'Public' methods -----------------------------------------------------------

-- OVERRIDE
function IceCustomCDBar.prototype:Enable(core)
	IceCustomCDBar.super.prototype.Enable(self, core)

	self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "UpdateCustomBar")

	self:Show(true)

	self:UpdateCustomBar()
	
	if self.moduleSettings.auraIconXOffset == nil then
		self.moduleSettings.auraIconXOffset = 40
	end
	if self.moduleSettings.auraIconYOffset == nil then
		self.moduleSettings.auraIconYOffset = 0
	end
end


function IceCustomCDBar.prototype:Disable(core)
	IceCustomCDBar.super.prototype.Disable(self, core)

	self:CancelScheduledEvent(self.elementName)
end

-- OVERRIDE
function IceCustomCDBar.prototype:GetDefaultSettings()
	local settings = IceCustomCDBar.super.prototype.GetDefaultSettings(self)

	settings["enabled"] = true
	settings["shouldAnimate"] = false
	settings["desiredLerpTime"] = 0
	settings["lowThreshold"] = 0
	settings["side"] = IceCore.Side.Right
	settings["offset"] = 8
	settings["upperText"]=""
	settings["usesDogTagStrings"] = false
	settings["lockLowerFontAlpha"] = false
	settings["lowerText"] = ""
	settings["lowerTextVisible"] = false
	settings["isCustomBar"] = false
	settings["cooldownToTrack"] = ""
	settings["barColor"] = {r=1, g=0, b=0, a=1}
	settings["displayWhenEmpty"] = false
	settings["hideAnimationSettings"] = true
	settings["cooldownTimerDisplay"] = "minutes"
	settings["customBarType"] = "CD"
	settings["maxDuration"] = 0
	settings["displayAuraIcon"] = false
	settings["auraIconXOffset"] = 40
	settings["auraIconYOffset"] = 0

	return settings
end

function IceCustomCDBar.prototype:CreateBar()
	IceCustomCDBar.super.prototype.CreateBar(self)

	if not self.barFrame.icon then
		self.barFrame.icon = self.barFrame:CreateTexture(nil, "LOW")
		-- default texture so that 'config mode' can work without activating the bar first
		self.barFrame.icon:SetTexture("Interface\\Icons\\Spell_Frost_Frost")
		self.barFrame.icon:SetWidth(20)
		self.barFrame.icon:SetHeight(20)
		-- this cuts off the border around the buff icon
		self.barFrame.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		self.barFrame.icon:SetDrawLayer("OVERLAY")
	end
	self:PositionIcons()
end

function IceCustomCDBar.prototype:PositionIcons()
	if not self.barFrame or not self.barFrame.icon then
		return
	end

	self.barFrame.icon:ClearAllPoints()
	self.barFrame.icon:SetPoint("TOPLEFT", self.frame, "TOPLEFT", self.moduleSettings.auraIconXOffset, self.moduleSettings.auraIconYOffset)
end

function IceCustomCDBar.prototype:Redraw()
	IceCustomCDBar.super.prototype.Redraw(self)

	self:UpdateCustomBar()
end

-- OVERRIDE
function IceCustomCDBar.prototype:GetOptions()
	local opts = IceCustomCDBar.super.prototype.GetOptions(self)

	opts.textSettings.args.upperTextString.hidden = false
	opts.textSettings.args.lowerTextString.hidden = false

	opts["customHeader"] = {
		type = 'header',
		name = "Custom CD settings",
		order = 20.1,
	}

	opts["deleteme"] = {
		type = 'execute',
		name = 'Delete me',
		desc = 'Deletes this custom module and all associated settings. Cannot be undone!',
		func = function()
			local dialog = StaticPopup_Show("ICEHUD_DELETE_CUSTOM_MODULE")
			if dialog then
				dialog.data = self
			end
		end,
		order = 20.2,
	}

	opts["name"] = {
		type = 'text',
		name = 'Bar name',
		desc = 'The name of this bar (must be unique!).\n\nRemember to press ENTER after filling out this box with the name you want or it will not save.',
		get = function()
			return self.elementName
		end,
		set = function(v)
			if v ~= "" then
				IceHUD.IceCore:RenameDynamicModule(self, v)
			end
		end,
		disabled = function()
			return not self.moduleSettings.enabled
		end,
		usage = "<a name for this bar>",
		order = 20.3,
	}

	opts["cooldownToTrack"] = {
		type = 'text',
		name = "Spell to track",
		desc = "Which spell cooldown this bar will be tracking.\n\nRemember to press ENTER after filling out this box with the name you want or it will not save.",
		get = function()
			return self.moduleSettings.cooldownToTrack
		end,
		set = function(v)
			if self.moduleSettings.cooldownToTrack == self.moduleSettings.upperText then
				self.moduleSettings.upperText = v
			end
			self.moduleSettings.cooldownToTrack = v
			self:Redraw()
			self:UpdateCustomBar()
		end,
		disabled = function()
			return not self.moduleSettings.enabled
		end,
		usage = "<which spell to track>",
		order = 20.6,
	}

	opts["barColor"] = {
		type = 'color',
		name = 'Bar color',
		desc = 'The color for this bar',
		get = function()
			return self:GetBarColor()
		end,
		set = function(r,g,b)
			self.moduleSettings.barColor.r = r
			self.moduleSettings.barColor.g = g
			self.moduleSettings.barColor.b = b
			self.barFrame.bar:SetVertexColor(self:GetBarColor())
		end,
		disabled = function()
			return not self.moduleSettings.enabled
		end,
		order = 20.8,
	}

	opts["displayWhenEmpty"] = {
		type = 'toggle',
		name = 'Display when empty',
		desc = 'Whether or not to display this bar even if the buff/debuff specified is not present.',
		get = function()
			return self.moduleSettings.displayWhenEmpty
		end,
		set = function(v)
			self.moduleSettings.displayWhenEmpty = v
			self:UpdateCustomBar()
		end,
		disabled = function()
			return not self.moduleSettings.enabled
		end,
		order = 20.9
	}

	opts["cooldownTimerDisplay"] = {
		type = 'text',
		name = 'Cooldown timer display',
		desc = 'How to display the buff timer next to the name of the buff on the bar',
		get = function()
			return self.moduleSettings.cooldownTimerDisplay
		end,
		set = function(v)
			self.moduleSettings.cooldownTimerDisplay = v
			self:UpdateCustomBar()
		end,
		disabled = function()
			return not self.moduleSettings.enabled
		end,
		validate = validBuffTimers,
		order = 21
	}
	
	opts["maxDuration"] = {
		type = 'text',
		name = "Maximum duration",
		desc = "Maximum Duration for the bar (the bar will remained full if it has longer than maximum remaining).  Leave 0 for spell duration.\n\nRemember to press ENTER after filling out this box with the name you want or it will not save.",
		get = function()
			return self.moduleSettings.maxDuration
		end,
		set = function(v)
			if not v or not tonumber(v) then
				v = 0
			end
			self.moduleSettings.maxDuration = v
			self:Redraw()
		end,
		disabled = function()
			return not self.moduleSettings.enabled
		end,
		usage = "<the maximum duration for a bar>",
		order = 21.1,
	}
	
	opts["headerIcons"] = {
		type = 'header',
		name = 'Icons',
		order = 40
	}
	
	opts["displayAuraIcon"] = {
		type = 'toggle',
		name = "Display aura icon",
		desc = "Whether or not to display an icon for the aura that this bar is tracking",
		get = function()
			return self.moduleSettings.displayAuraIcon
		end,
		set = function(v)
			self.moduleSettings.displayAuraIcon = v
			if self.barFrame.icon then
				if v then
					self.barFrame.icon:Show()
				else
					self.barFrame.icon:Hide()
				end
			end
		end,
		disabled = function()
			return not self.moduleSettings.enabled
		end,
		usage = "<whether or not to display an icon for this bar's tracked spell>",
		order = 40.1,
	}
	
	opts["auraIconXOffset"] = {
		type = 'range',
		min = -250,
		max = 250,
		step = 1,
		name = "Aura icon horizontal offset",
		desc = "Adjust the horizontal position of the aura icon",
		get = function()
			return self.moduleSettings.auraIconXOffset
		end,
		set = function(v)
			self.moduleSettings.auraIconXOffset = v
			self:PositionIcons()
		end,
		disabled = function()
			return not self.moduleSettings.enabled or not self.moduleSettings.displayAuraIcon
		end,
		usage = "<adjusts the spell icon's horizontal position>",
		order = 40.2,
	}

	opts["auraIconYOffset"] = {
		type = 'range',
		min = -250,
		max = 250,
		step = 1,
		name = "Aura icon vertical offset",
		desc = "Adjust the vertical position of the aura icon",
		get = function()
			return self.moduleSettings.auraIconYOffset
		end,
		set = function(v)
			self.moduleSettings.auraIconYOffset = v
			self:PositionIcons()
		end,
		disabled = function()
			return not self.moduleSettings.enabled or not self.moduleSettings.displayAuraIcon
		end,
		usage = "<adjusts the spell icon's vertical position>",
		order = 40.3,
	}

	return opts
end

function IceCustomCDBar.prototype:GetBarColor()
	return self.moduleSettings.barColor.r, self.moduleSettings.barColor.g, self.moduleSettings.barColor.b, self.alpha
end

-- 'Protected' methods --------------------------------------------------------

function IceCustomCDBar.prototype:GetCooldownDuration(buffName)
		local now = GetTime()
		local localDuration = nil
		local localStart, localRemaining, hasCooldown = GetSpellCooldown(self.moduleSettings.cooldownToTrack)

		if (hasCooldown == 1) then
		    -- the item has a potential cooldown
			if (localStart > now) then
			    localRemaining = localRemaining + (localStart - now)
			    localDuration = localRemaining
			else
			    localRemaining = localRemaining + (localStart - now)
			    localDuration = (now - localStart) + localRemaining
			end
			
			if self.moduleSettings.maxDuration and self.moduleSettings.maxDuration ~= 0 then
				localDuration = tonumber(self.moduleSettings.maxDuration)
			end
			
			local name, rank, icon = GetSpellInfo(self.moduleSettings.cooldownToTrack)

			if localDuration > 1.5  then
				return localDuration, localRemaining, icon
			else
				localRemaining = self.cooldownEndTime - now
				if localRemaining > 0 then
					return self.cooldownDuration, localRemaining, icon
				else
					return nil, nil, nil
				end
			end
		else
			return nil, nil, nil
		end
end


function IceCustomCDBar.prototype:UpdateCustomBar(fromUpdate)
	local now = GetTime()
	local remaining = nil
	local auraIcon = nil

	if not fromUpdate then
		self.cooldownDuration, remaining, auraIcon =
			self:GetCooldownDuration(self.moduleSettings.cooldownToTrack)

		if not remaining then
			self.cooldownEndTime = 0
		else
			self.cooldownEndTime = remaining + now
		end

		if auraIcon ~= nil then
			self.barFrame.icon:SetTexture(auraIcon)
		end

		if IceHUD.IceCore:IsInConfigMode() or self.moduleSettings.displayAuraIcon then
			self.barFrame.icon:Show()
		else
			self.barFrame.icon:Hide()
		end
	end

	if self.cooldownEndTime and self.cooldownEndTime >= now then
		if not fromUpdate then
			self.frame:SetScript("OnUpdate", function() self:UpdateCustomBar(true) end)
		end

		self:Show(true)

		if not remaining then
			remaining = self.cooldownEndTime - now
		end

		self:UpdateBar(self.cooldownDuration ~= 0 and remaining / self.cooldownDuration or 0, "undef")
	else
		self:UpdateBar(0, "undef")
		self:Show(false)
		self.frame:SetScript("OnUpdate", nil)
	end

	if (remaining ~= nil) then
		local buffString = ""
		if self.moduleSettings.cooldownTimerDisplay == "seconds" then
			buffString = tostring(ceil(remaining or 0)) .. "s"
		else
			local seconds = ceil(remaining)%60
			local minutes = ceil(remaining)/60

			if self.moduleSettings.cooldownTimerDisplay == "minutes:seconds" then
				buffString = floor(minutes) .. ":" .. string.format("%02d", seconds)
			elseif self.moduleSettings.cooldownTimerDisplay == "minutes" then
				if minutes > 1 then
					buffString = ceil(minutes) .. "m"
				else
					buffString = ceil(remaining) .. "s"
				end
			end
		end
		self:SetBottomText1(self.moduleSettings.upperText .. " " .. buffString)
	else
		self.auraBuffCount = 0
		self:SetBottomText1(self.moduleSettings.upperText)
	end

	self.barFrame.bar:SetVertexColor(self:GetBarColor())
end

function IceCustomCDBar.prototype:OutCombat()
	IceCustomCDBar.super.prototype.OutCombat(self)

	self:UpdateCustomBar()
end

function IceCustomCDBar.prototype:Show(bShouldShow)
	if self.moduleSettings.displayWhenEmpty then
		if not self.bIsVisible then
			IceCustomCDBar.super.prototype.Show(self, true)
		end
	else
		IceCustomCDBar.super.prototype.Show(self, bShouldShow)
	end
end
