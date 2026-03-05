--[[------------------------------------------------------------------------------------------------
Title:					Static's Furnishing Improvements
Author:					Static_Recharge
Version:			  0.2.0
Description:		Adds functionality to the in game furnishing menus and placement UI
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local EM = EVENT_MANAGER
local SM = SCENE_MANAGER
local CRAFTING_STATIONS = 104


--[[------------------------------------------------------------------------------------------------
StaticsFurnishingImprovements Class Initialization
StaticsFurnishingImprovements    - Parent object containing all functions, tables, variables, constants and other data managers.
------------------------------------------------------------------------------------------------]]--
StaticsFurnishingImprovements = {}


--[[------------------------------------------------------------------------------------------------
StaticsFurnishingImprovements:Initialize()
Inputs:				None
Outputs:			None
Description:	Initializes all of the variables, object managers, slash commands and main event
							callbacks.
------------------------------------------------------------------------------------------------]]--
function StaticsFurnishingImprovements:Initialize()
	-- Static definitions
  self.addonName = "StaticsFurnishingImprovements"
	self.addonVersion = "0.2.0"
	self.author = "|CFF0000Static_Recharge|r"
	self.varsVersion = 1

	self.Defaults = {
		chatEnabled = true,
		debugEnabled = false,
		settingsChanged = true,
		depositSameFromInventory = true,
		depositSameFromHouse = true,
		depositCraftingStations = false,
		showRetrieveToOnHUD = true,
	}

	self.Dialogs = {
		DEPOSIT_SAME = {
			canQueue = false,
			title ={text = "Deposit Same from House",},
			mainText ={text = "This will move |cFFFF66<<1>>|r items from the current house to the Furniture Vault.\n\nAre you sure?",},
			buttons = {
				[1] = {
					text = SI_YES,
					callback = function(dialog)
						self:DepositSameFromHouse()
					end,
				},
				[2] = {
					text = SI_NO,
					callback = function(dialog)
						
					end,
				}
			}
		},
	}
	
	-- Session Variables
	self.Scenes = {
		housingEditorHUD = SM:GetScene("housingEditorHud"),
		housingEditorHUDUI = SM:GetScene("housingEditorHudUI"),
		furnitureVaultScene = SM:GetScene("furnitureVault"),
	}
	self.currentRetrieveTo = nil
	self.retrieveToChanged = false

	-- Saved Variables Initialization
	self.SV = ZO_SavedVars:NewAccountWide("StaticsFurnishingImprovementsWideVars", self.varsVersion, nil, self.Defaults, GetWorldName())

	-- Library Initialization
	local Options = {
		addonIdentifier = "SFI",
		prefixColor = "0086B3",
		textColor = "FFFFFF",
		chatEnabled = self.SV.chatEnabled,
		debugEnabled = self.SV.debugEnabled,
	}
	self.Chat = LibStatic.CHAT:New(Options)

	-- Child Initialization
	self.Settings = self.SETTINGS:New(self)

	-- Hooks
	self:StowCraftingStationsHook()	
	
	-- Event Registrations and Callbacks
  EM:RegisterForEvent(self.addonName, EVENT_PLAYER_ACTIVATED, function(_, ...) self:OnPlayerActivated(...) end)

	-- Slash Commands
	SLASH_COMMANDS["/sfidepositsamefromhouse"] = function() self:DepositSameFromHouseDialog() end

	-- Hotkey Associations
	self:AddDepostSameKeybindButton()
	ZO_CreateStringId("SI_BINDING_NAME_SFI_Deposit_Same_From_House", "Deposit Same From House")

	-- Dialogs
	ESO_Dialogs[self.addonName .. "Deposit_Same_Confirm"] = self.Dialogs.DEPOSIT_SAME
  
	self.initialized = true
end


--[[------------------------------------------------------------------------------------------------
StaticsFurnishingImprovements:OnPlayerActivated()
Inputs:				None
Outputs:			None
Description:	Shows or hides the retrieve to menu
------------------------------------------------------------------------------------------------]]--
function StaticsFurnishingImprovements:OnPlayerActivated()
	self.Chat:Debug("OnPlayerActivated started.")
	if IsOwnerOfCurrentHouse() then
		if self.SV.showRetrieveToOnHUD then
			self.Scenes.housingEditorHUD:AddFragment(HOUSING_FURNITURE_RETRIEVE_TO_FRAGMENT)
		else
			self.Scenes.housingEditorHUD:RemoveFragment(HOUSING_FURNITURE_RETRIEVE_TO_FRAGMENT)
		end
		self.Scenes.housingEditorHUDUI:AddFragment(HOUSING_FURNITURE_RETRIEVE_TO_FRAGMENT)
	else
		self.Scenes.housingEditorHUD:RemoveFragment(HOUSING_FURNITURE_RETRIEVE_TO_FRAGMENT)
		self.Scenes.housingEditorHUDUI:RemoveFragment(HOUSING_FURNITURE_RETRIEVE_TO_FRAGMENT)
	end  
end


--[[------------------------------------------------------------------------------------------------
StaticsFurnishingImprovements:StowCraftingStationsHook()
Inputs:				None
Outputs:			None
Description:	Automatically stores crafting stations in the furnishing vault when picking them up from a house.
------------------------------------------------------------------------------------------------]]--
function StaticsFurnishingImprovements:StowCraftingStationsHook()
	local function preHookRetrieve()
		if not self.SV.depositCraftingStations then return end

		local link = GetItemLinkFurnitureDataId(GetPlacedFurnitureLink(HousingEditorGetSelectedFurnitureId()))
		local _, subCategory = GetFurnitureDataInfo(link)
		self.Chat:Debug(zo_strformat("link: <<1>>, subCategory: <<2>>", link, subCategory))
		if subCategory == CRAFTING_STATIONS then
			self.currentRetrieveTo = HousingEditorGetRetrieveToBag()
			self.Chat:Msg(zo_strformat("<<1>> sent to the Furnishing Vault automatically.", link))
			if self.currentRetrieveTo ~= BAG_FURNITURE_VAULT then
				HousingEditorSetRetrieveToBag(BAG_FURNITURE_VAULT)
				self.retrieveToChanged = true
			end
		end
	end

	local function postHookRetrieve()
		if not self.SV.depositCraftingStations then return end

		if self.retrieveToChanged then
			HousingEditorSetRetrieveToBag(self.currentRetrieveTo)
			self.retrieveToChanged = false
		end
	end

	ZO_PreHook("HousingEditorRequestRemoveSelectedFurniture", preHookRetrieve)
	ZO_PostHook("HousingEditorRequestRemoveSelectedFurniture", postHookRetrieve)
	ZO_PreHook("HousingEditorRequestRemoveFurniture", preHookRetrieve)
	ZO_PostHook("HousingEditorRequestRemoveFurniture", postHookRetrieve)
end


--[[------------------------------------------------------------------------------------------------
StaticsFurnishingImprovements:DepositSameFromInventory()
Inputs:				None
Outputs:			None
Description:	Deposits already existing stacks into the furnishing vault
------------------------------------------------------------------------------------------------]]--
function StaticsFurnishingImprovements:DepositSameFromInventory()
	if not self.SV.depositSameFromInventory then return end

  local FurnitureCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_FURNITURE_VAULT)
	local backpackCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
	local count = 0

	for furnitureIndex, furnitureData in pairs(FurnitureCache) do
		local furnitureID = GetItemId(BAG_FURNITURE_VAULT, furnitureIndex)
		for backpackIndex, backpackData in pairs(backpackCache) do
			local backpackID = GetItemId(BAG_BACKPACK, backpackIndex)
			local link = GetItemLink(BAG_BACKPACK, backpackIndex)
			self.Chat:Debug(zo_strformat("furnitureID: <<1>>, backpackID: <<2>>", furnitureID, backpackID))
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
				self.Chat:Msg(zo_strformat("<<1>> moved to furnishing vault.", link))
				count = count + 1
			end			
		end
	end
	self.Chat:Msg(zo_strformat("<<1>> items moved to furnishing vault.", count))
end


--[[------------------------------------------------------------------------------------------------
StaticsFurnishingImprovements:DepositSameFromHouseDialog()
Inputs:				None
Outputs:			None
Description:	Starts the dialog to confirm moving furniture from the house to the furnishing vault.
------------------------------------------------------------------------------------------------]]--
function StaticsFurnishingImprovements:DepositSameFromHouseDialog()
	if not self.SV.depositSameFromHouse then return end

  local FurnitureCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_FURNITURE_VAULT)

	-- Cache house furniture
	local HouseCache = {}
	local id = GetNextPlacedHousingFurnitureId()
	while id do
		local link = GetPlacedFurnitureLink(id)
		local furniture = {
			id = id,
			link = link,
			data = GetItemLinkFurnitureDataId(link)
		}
		table.insert(HouseCache, furniture)
		id = GetNextPlacedHousingFurnitureId(id)
	end

	-- Count how many would be removed and index them
	self.found = {}
	for furnitureIndex, furnitureData in pairs(FurnitureCache) do
		local furnitureID = GetItemId(BAG_FURNITURE_VAULT, furnitureIndex)
		for houseIndex, houseData in pairs(HouseCache) do
			local houseID = GetItemLinkItemId(houseData.link)
			local link = houseData.link
			self.Chat:Debug(zo_strformat("furnitureID: <<1>>, houseID: <<2>>", furnitureID, houseID))
			if furnitureID == houseID then
				table.insert(self.found, houseData)
			end			
		end
	end

	-- Show confirm dialog
	if #self.found > 0 then
		ZO_Dialogs_ShowDialog(self.addonName .. self.Dialogs.DEPOSIT_SAME, nil, {mainTextParams={#self.found}}, false)
	else
		self.Chat:Msg("No matching furnishings found to move to the Furnishing Vault.")
	end
end


--[[------------------------------------------------------------------------------------------------
StaticsFurnishingImprovements:DepositSameFromHouse()
Inputs:				found 															- Table containing the furniture data to remove
Outputs:			None
Description:	Moves furniture from the house to the furnishing vault.
------------------------------------------------------------------------------------------------]]--
function StaticsFurnishingImprovements:DepositSameFromHouse()
  -- If dialog passed then remove the furniture to the furnishing vault
	self.currentRetrieveTo = HousingEditorGetRetrieveToBag()
	HousingEditorSetRetrieveToBag(BAG_FURNITURE_VAULT)
	for index, data in ipairs(self.found) do
		HousingEditorRequestRemoveFurniture(data.id)
		self.Chat:Msg(zo_strformat("<<1>> moved to furnishing vault from house.", data.link))
	end
	self.Chat:Msg(zo_strformat("<<1>> items moved to furnishing vault from house.", #self.found))
	HousingEditorSetRetrieveToBag(self.currentRetrieveTo)
end


--[[------------------------------------------------------------------------------------------------
StaticsFurnishingImprovements:AddDepostSameKeybindButton()
Inputs:				None
Outputs:			None
Description:	Adds the Deposit Same keybinding to the strip.
------------------------------------------------------------------------------------------------]]--
function StaticsFurnishingImprovements:AddDepostSameKeybindButton()
	local furnitureVaultLeftKeybindStrip = {
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
		name = "Deposit Same",
		keybind = "UI_SHORTCUT_TERTIARY",
		callback = function() self:DepositSameFromInventory() end,
	}

	self.Scenes.furnitureVaultScene:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_SHOWING and self.SV.depositSameFromInventory then
			KEYBIND_STRIP:AddKeybindButton(furnitureVaultLeftKeybindStrip)
		elseif newState == SCENE_HIDDEN then
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
	StaticsFurnishingImprovements:Initialize()
end)