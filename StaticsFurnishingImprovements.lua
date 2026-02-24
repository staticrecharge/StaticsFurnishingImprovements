--[[------------------------------------------------------------------------------------------------
Title:					Static's Furnishing Improvements
Author:					Static_Recharge
Version:			  0.0.1
Description:		Adds functionality to the in game furnishing menus and placement UI
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local EM = EVENT_MANAGER
local SM = SCENE_MANAGER


--[[------------------------------------------------------------------------------------------------
FI Class Initialization
FI    - Parent object containing all functions, tables, variables, constants and other data managers.
------------------------------------------------------------------------------------------------]]--
local FI = ZO_InitializingObject:Subclass()


--[[------------------------------------------------------------------------------------------------
FI:Initialize()
Inputs:				None
Outputs:			None
Description:	Initializes all of the variables, object managers, slash commands and main event
							callbacks.
------------------------------------------------------------------------------------------------]]--
function FI:Initialize()
	-- Static definitions
  self.addonName = "StaticsFurnishingImprovements"
	self.addonVersion = "0.0.1"
	self.author = "|CFF0000Static_Recharge|r"
	self.varsVersion = 1
	
	-- Session variables

	-- Saved variables initialization
	--self.SV = ZO_SavedVars:NewAccountWide("StaticsFurnishingImprovementsWideVars", self.varsVersion, nil, self.Defaults, nil)

	-- Child Initilization
	
	-- Event Registrations and Callbacks
  self:HousingEditorHUDUISceneChangeCallback()

	-- Slash Commands
	SLASH_COMMANDS["/sfideposit"] = function() self:DepositSame() end
  
	self.initialized = true
end


--[[------------------------------------------------------------------------------------------------
FI:HousingEditorHUDUISceneChangeCallback()
Inputs:				None
Outputs:			None
Description:	Shows or hides the retrieve to menu
------------------------------------------------------------------------------------------------]]--
function FI:HousingEditorHUDUISceneChangeCallback()
  HOUSING_EDITOR_HUD_UI_SCENE:RegisterCallback("StateChange",  function(oldState, newState)
    if HOUSING_EDITOR_STATE:IsLocalPlayerHouseOwner() and GetHousingEditorMode() == HOUSING_EDITOR_MODE_PLACEMENT then
      KEYBOARD_HOUSING_FURNITURE_BROWSER.placeablePanel:RefreshFilters()
      SM:AddFragment(HOUSING_FURNITURE_RETRIEVE_TO_FRAGMENT)
    else
      SM:RemoveFragment(HOUSING_FURNITURE_RETRIEVE_TO_FRAGMENT)
    end
  end)
end


--[[------------------------------------------------------------------------------------------------
FI:DepositSame()
Inputs:				None
Outputs:			None
Description:	Deposits already existing stacks into the furnishing vault
------------------------------------------------------------------------------------------------]]--
function FI:DepositSame()
  local bag, style = BAG_BACKPACK, LINK_STYLE_BRACKETS
	local slot = ZO_GetNextBagSlotIndex(bag)
	local Inventory = {}
	local FurnishingVault = {}
	while slot do
		if HasItemInSlot(bag, slot)	and GetItemType(bag, slot) == ITEMTYPE_FURNISHING then
			table.insert(Inventory, GetItemId(bag, slot))
		end
		slot = ZO_GetNextBagSlotIndex(bag, slot)
	end
	bag = BAG_FURNITURE_VAULT
	slot = ZO_GetNextBagSlotIndex(bag)
	while slot do
		if FurnishingVault[GetItemId(bag, slot)] then
			-- deposit
		end
		slot = ZO_GetNextBagSlotIndex(bag, slot)
	end
end


--[[------------------------------------------------------------------------------------------------
Main add-on event registration. Creates the global object, StaticsLetterOpener, of the LO class.
------------------------------------------------------------------------------------------------]]--
EM:RegisterForEvent("StaticsFurnishingImprovements", EVENT_ADD_ON_LOADED, function(eventCode, addonName)
	if addonName ~= "StaticsFurnishingImprovements" then return end
	EM:UnregisterForEvent("StaticsFurnishingImprovements", EVENT_ADD_ON_LOADED)
	StaticsFurnishingImprovements = FI:New()
end)