--[[------------------------------------------------------------------------------------------------
Title:					Static's Furnishing Improvements
Author:					Static_Recharge
Version:			  0.0.2
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
	self.addonVersion = "0.0.2"
	self.author = "|CFF0000Static_Recharge|r"
	self.varsVersion = 1
	
	-- Session variables

	-- Saved variables initialization
	--self.SV = ZO_SavedVars:NewAccountWide("StaticsFurnishingImprovementsWideVars", self.varsVersion, nil, self.Defaults, nil)

	-- Child 
	
	-- Hooks
	self:KeybindStripAdd()
	
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
  local FurnitureCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_FURNITURE_VAULT)
	local backpackCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)

	for furnitureIndex, furnitureData in pairs(FurnitureCache) do
		local furnitureID = GetItemId(BAG_FURNITURE_VAULT, furnitureIndex)
		for backpackIndex, backpackData in pairs(backpackCache) do
			local backpackID = GetItemId(BAG_BACKPACK, backpackIndex)
			if furnitureID == backpackID then
				if IsProtectedFunction("PickupInventoryItem") then
					CallSecureProtected("PickupInventoryItem", BAG_BACKPACK, backpackIndex)
				else
					PickupInventoryItem(BAG_BACKPACK, backpackIndex)
				end
				if IsProtectedFunction("PlaceInTransfer") then
					CallSecureProtected("PlaceInTransfer")
				else
					PlaceInTransfer()
				end
			end			
		end
	end
end


--[[------------------------------------------------------------------------------------------------
FI:KeybindStripAdd()
Inputs:				None
Outputs:			None
Description:	Adds the Deposit Same keybinding to the strip.
------------------------------------------------------------------------------------------------]]--
function FI:KeybindStripAdd()
	local furnitureVaultLeftKeybindStrip = {
			alignment = KEYBIND_STRIP_ALIGN_LEFT,
			name = "Deposit Same",
			keybind = "UI_SHORTCUT_QUINARY",
			callback = function() self:DepositSame() end,
		}

	FURNITURE_VAULT_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
    if newState == SCENE_FRAGMENT_SHOWING then
			KEYBIND_STRIP:AddKeybindButton(furnitureVaultLeftKeybindStrip)
    elseif newState == SCENE_FRAGMENT_HIDDEN then
      KEYBIND_STRIP:RemoveKeybindButton(furnitureVaultLeftKeybindStrip)
    end
  end)
end


--[[------------------------------------------------------------------------------------------------
Main add-on event registration. Creates the global object, StaticsLetterOpener, of the LO class.
------------------------------------------------------------------------------------------------]]--
EM:RegisterForEvent("StaticsFurnishingImprovements", EVENT_ADD_ON_LOADED, function(eventCode, addonName)
	if addonName ~= "StaticsFurnishingImprovements" then return end
	EM:UnregisterForEvent("StaticsFurnishingImprovements", EVENT_ADD_ON_LOADED)
	StaticsFurnishingImprovements = FI:New()
end)