--[[------------------------------------------------------------------------------------------------
Title:          Settings
Author:         Static_Recharge
Description:    Creates and controls the settings menu and related saved variables.
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local WM = WINDOW_MANAGER
local SM = SCENE_MANAGER
local LCM = LibCustomMenu


--[[------------------------------------------------------------------------------------------------
Queue Class Initialization
Queue    													            - Parent object containing all functions, tables, variables, constants and other data managers.
├─ :IsInitialized()                               - Returns true if the object has been successfully initialized.
├─ :CreateSettingsPanel()													- Creates and registers the settings panel with LibAddonMenu.
├─ :Update()                											- Updates the settings panel in LibAddonMenu.
├─ :Changed()               							- Fired when the player first loads in after a settings reset is forced.
└─ :GetParent()                                   - Returns the parent object of this object for reference to parent variables.
------------------------------------------------------------------------------------------------]]--
local Queue = ZO_InitializingObject:Subclass()


--[[------------------------------------------------------------------------------------------------
Queue:Initialize(Parent)
Inputs:				Parent 															- The parent object containing other required information.  
Outputs:			None
Description:	Initializes all of the variables and tables.
------------------------------------------------------------------------------------------------]]--
function Queue:Initialize(Parent)
  self.Parent = Parent
  self.ListPool = {}
  self.List = {}

  -- Controls
  local p = GetControl("SFI_Panel")
  self.C = {
    Panel = p,
    CloseButton = p:GetNamedChild("CloseButton"),
    ScrollBox = p:GetNamedChild("ScrollBox"),
  }

  -- Libraries
  ZO_CreateStringId("SI_BINDING_NAME_ADD_VAULT_QUEUE", "Add to Vault Queue")
  LCM:RegisterContextMenu(function(...) self:Add(...) end, category)

  -- Events and Callbacks
  self:DepositQueue()

  -- Slash Commands
  SLASH_COMMANDS["/sfiqueue"] = function() self:ShowPanel() end

  self:RestorePanel()

	self.initialized = true
end


--[[------------------------------------------------------------------------------------------------
Queue:IsInitialized()
Inputs:				None
Outputs:			initialized                         - bool for object initialized state
Description:	Returns true if the object has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function Queue:IsInitialized()
  return self.initialized
end


--[[------------------------------------------------------------------------------------------------
Queue:OnMoveStop()
Inputs:				None
Outputs:			None
Description:	Stores the new window position.
------------------------------------------------------------------------------------------------]]--
function Queue:OnMoveStop()
  local Parent = self:GetParent()
  local sv = Parent.SV
  local c = self.C
  sv.queueLeft = c.Panel:GetLeft()
	sv.queueTop = c.Panel:GetTop()
end


--[[------------------------------------------------------------------------------------------------
Queue:RestorePanel()
Inputs:				None
Outputs:			None
Description:	Restores the window position.
------------------------------------------------------------------------------------------------]]--
function Queue:RestorePanel()
  local Parent = self:GetParent()
  local sv = Parent.SV
  local c = self.C
  local left = sv.queueLeft
	local top = sv.queueTop
	if left ~= nil and top ~= nil then
		c.Panel:ClearAnchors()
		c.Panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
	end
end


--[[------------------------------------------------------------------------------------------------
Queue:ResetPosition()
Inputs:				None
Outputs:			None
Description:	Resets the window position.
------------------------------------------------------------------------------------------------]]--
function Queue:ResetPosition()
  local Parent = self:GetParent()
  local sv = Parent.SV
  sv.left = nil
  sv.top = nil
  self:RestorePanel()
end


--[[------------------------------------------------------------------------------------------------
Queue:ShowPanel()
Inputs:				show                                - (optional) forces the window to a shown state if true
Outputs:			None
Description:	Shows/Hides or Toggles the window.
------------------------------------------------------------------------------------------------]]--
function Queue:ShowPanel(show)
  local Parent = self:GetParent()
  if not Parent.SV.queueEnabled then return end
  local c = self.C
  if show == nil then
    c.Panel:SetHidden(not c.Panel:IsHidden())
  else
    c.Panel:SetHidden(not show)
  end
  if c.Panel:IsHidden() then
    SM:SetInUIMode(false)
  else
    SM:SetInUIMode(true)
  end
end


--[[------------------------------------------------------------------------------------------------
Queue:UpdateScrollList()
Inputs:				None
Outputs:			None
Description:	Updates the Queue list.
------------------------------------------------------------------------------------------------]]--
function Queue:UpdateScrollList()	
	for i,v in pairs(self.ListPool) do
		v:SetHidden(true)
	end
	local parent = self.C.ScrollBox
	local name = "SFIListEntry"
	local template = "SFIListTemplate"
	for i,v in ipairs(self.List) do
		local c = {}
		if self.ListPool[i] then
			c = self.ListPool[i]
		else
			c = WM:CreateControlFromVirtual(name, parent, template, i)
			c:SetParent(self.C.ScrollBox:GetNamedChild("ScrollChild"))
			table.insert(self.ListPool, c)
			c:ClearAnchors()
			c:SetAnchor(TOPLEFT, ScrollBoxScrollChild, TOPLEFT, 4, (i-1) * 32)
		end
		c:SetText(zo_strformat("|t24:24:<<1>>|t <<2>>", v.icon, v.link))
		c:SetHidden(false)
		c:SetHandler("OnMouseUp", function(self_, button) if button == 2 then self:Remove(i) end end)
		c:SetHandler("OnMouseEnter", function(self_) self:ShowTooltip(i) end)
		c:SetHandler("OnMouseExit", function(self_) self:HideTooltip() end)
	end
end


--[[------------------------------------------------------------------------------------------------
Queue:Remove()
Inputs:				index                               - the index of the item to remove from the Queue
Outputs:			None
Description:	Removes the indexed item from the list.
------------------------------------------------------------------------------------------------]]--
function Queue:Remove(index)
	table.remove(self.List, index)
	self:UpdateScrollList()
end


--[[------------------------------------------------------------------------------------------------
Queue:ShowTooltip()
Inputs:				index                               - the index of the item to show
Outputs:			None
Description:	Shows the tooltip for the indexed item.
------------------------------------------------------------------------------------------------]]--
function Queue:ShowTooltip(index)
	local itemLink = self.List[index].link
	InitializeTooltip(ItemTooltip, self.C.Panel, RIGHT, -5, 0, LEFT)
	ItemTooltip:SetLink(itemLink)
end


--[[------------------------------------------------------------------------------------------------
Queue:HideTooltip()
Inputs:				None
Outputs:			None
Description:	Hides the tooltip.
------------------------------------------------------------------------------------------------]]--
function Queue:HideTooltip()
	ClearTooltip(ItemTooltip)
end


--[[------------------------------------------------------------------------------------------------
Queue:Add()
Inputs:				inventorySlot                       - inventory slot information
              slotActions                         - slot actions to add to
Outputs:			None
Description:	Adds the furniture item to the Queue from the context menu. Only works from inventory scene.
------------------------------------------------------------------------------------------------]]--
function Queue:Add(inventorySlot, slotActions)
  local Parent = self:GetParent()
  if not Parent.SV.queueEnabled then return end
  local valid = ZO_Inventory_GetBagAndIndex(inventorySlot)
  if not valid then return end
  local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
  local itemType = GetItemType(bagId, slotIndex)
  local id = GetItemId(bagId, slotIndex)
  local scene = SM:GetCurrentScene()
  if itemType ~= ITEMTYPE_FURNISHING or scene ~= Parent.Scenes.inventoryScene then return end
  slotActions:AddCustomSlotAction(SI_BINDING_NAME_ADD_VAULT_QUEUE, function()
    local icon= GetItemInfo(bagId, slotIndex)
    local link = GetItemLink(bagId, slotIndex)
    local data = {
      icon = icon,
      link = link,
      id = id,
    }
    table.insert(self.List, data)
    Parent.Chat:Msg(zo_strformat("<<1>> added to the Vault Queue."))
    self:UpdateScrollList()
    if Parent.SV.queueShowAfterAdd then
      self:ShowPanel(true)
    end
  end, "")
end


--[[------------------------------------------------------------------------------------------------
Queue:DepositQueue()
Inputs:				None
Outputs:			None
Description:	Automatically deposits the Queue into the furnishing vault.
------------------------------------------------------------------------------------------------]]--
function Queue:DepositQueue()
  local Parent = self:GetParent()
	Parent.Scenes.furnitureVaultScene:RegisterCallback("StateChange", function(oldState, newState)
    if not Parent.SV.queueEnabled then return end
		if newState == SCENE_SHOWING and #self.List > 0 then
			local backpackCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
      while #self.List > 0 do
        local found = false
        local qID = self.List[1].id
        local qLink = self.List[1].link
        for backpackIndex, backpackData in pairs(backpackCache) do
          local backpackID = GetItemId(BAG_BACKPACK, backpackIndex)
          local link = GetItemLink(BAG_BACKPACK, backpackIndex)
          local _, backpackQty = GetItemInfo(BAG_BACKPACK, backpackIndex)
          Parent.Chat:Debug(zo_strformat("qID: <<1>>, backpackID: <<2>>", qID, backpackID))
          if qID == backpackID then
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
            Parent.Chat:Msg(zo_strformat("<<1>> x<<2>> moved to furnishing vault.", link, backpackQty))
            found = true
          end	
        end
        if not found then
          Parent.Chat:Msg(zo_strformat("<<1>>not found in inventory.", link))
        end
        table.remove(self.List, 1)
      end
      Parent.Chat:Msg("Item transfers from Queue finished.")
      self:UpdateScrollList()
		end
	end)
end


--[[------------------------------------------------------------------------------------------------
Queue:Update()
Inputs:				None
Outputs:			None
Description:	Updates the settings panel in LibAddonMenu.
------------------------------------------------------------------------------------------------]]--
function Queue:Update()
	local Parent = self:GetParent()
	if not Parent.LAMReady then return end
end


--[[------------------------------------------------------------------------------------------------
Queue:Changed()
Inputs:				None
Outputs:			None
Description:	Sends a message the the settings have been reset.
------------------------------------------------------------------------------------------------]]--
function Queue:Changed()
	local Parent = self:GetParent()
	if not Parent.SV.settingsChanged then return end
	Parent.SV.settingsChanged = false
	Parent.Chat:Msg("Settings have been reset, please ensure they are to your preference.")
end


--[[------------------------------------------------------------------------------------------------
Queue:GetParent()
Inputs:				None
Outputs:			Parent          										- The parent object of this object.
Description:	Returns the parent object of this object for reference to parent variables.
------------------------------------------------------------------------------------------------]]--
function Queue:GetParent()
  return self.Parent
end

--[[------------------------------------------------------------------------------------------------
Global template assignment
------------------------------------------------------------------------------------------------]]--
StaticsFurnishingImprovements.QUEUE = Queue