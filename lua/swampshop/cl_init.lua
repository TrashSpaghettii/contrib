﻿-- This file is subject to copyright - contact swampservers@gmail.com for more information.
-- INSTALL: CINEMA
include("sh_init.lua")
include("cl_draw.lua")
include("vgui/menu.lua")
include("vgui/panels.lua")
include("vgui/item.lua")
include("vgui/preview.lua")
include("vgui/customizer.lua")
include("vgui/givepoints.lua")
local wasf3down = false
local wascontextdown = false
OLDBINDSCONVAR = CreateClientConVar("swamp_old_binds", "0", true, false)

concommand.Add("menu_context", function()
    if not OLDBINDSCONVAR:GetBool() then
        SS_ToggleMenu()
    end
end)

concommand.Add("+menu_context", function()
    if not OLDBINDSCONVAR:GetBool() then
        SS_ToggleMenu()
    end
end)

concommand.Add("swamp_shop", function()
    SS_ToggleMenu()
end)

hook.Add("Think", "PSToggler", function()
    local isf3down = input.IsKeyDown(KEY_F3)

    if isf3down and not wasf3down then
        if OLDBINDSCONVAR:GetBool() then
            SS_ToggleMenu()
        else
            LocalPlayerNotify("The shop binding is now " .. tostring(input.LookupBinding("menu_context") or "unbound"):upper() .. " (bind +menu_context, or bind swamp_shop, or set swamp_old_binds 1)")
        end
    end

    wasf3down = isf3down
end)

concommand.Add("ps_togglemenu", function(ply, cmd, args)
    SS_ToggleMenu()
end)

CreateClientConVar("ps_darkmode", "0", true)

function SetPointshopTheme(dark)
    SS_DarkMode = dark

    if SS_DarkMode then
        SS_TileBGColor = Color(37, 37, 37)
        SS_GridBGColor = Color(33, 33, 33)
        SS_BotBGColor = Color(33, 33, 33)
        SS_SwitchableColor = Color(200, 200, 200)
    else
        SS_TileBGColor = Color(234, 234, 234)
        SS_GridBGColor = Color(200, 200, 200)
        SS_BotBGColor = Color(64, 64, 64)
        SS_SwitchableColor = Color(0, 0, 0)
    end

    if IsValid(SS_CustomizerPanel) then
        SS_CustomizerPanel:Remove()
    end

    if IsValid(SS_ShopMenu) then
        if SS_ShopMenu:IsVisible() then
            SS_ShopMenu:Remove()
            SS_ShopMenu = vgui.Create('DPointShopMenu')
            SS_ShopMenu:Show()
        else
            SS_ShopMenu:Remove()
            SS_ShopMenu = vgui.Create('DPointShopMenu')
            SS_ShopMenu:SetVisible(false)
        end
    end
end

SetPointshopTheme(GetConVar("ps_darkmode"):GetBool())

cvars.AddChangeCallback("ps_darkmode", function(cvar, old, new)
    SetPointshopTheme(tobool(new))
end)

function SS_ReloadMenu()
    if IsValid(SS_CustomizerPanel) then
        SS_CustomizerPanel:Close()
    end

    if IsValid(SS_ShopMenu) then
        SS_ShopMenu:Remove()
    end
end

concommand.Add("ps_destroymenu", function(ply, cmd, args)
    SS_ReloadMenu()
end)

function SS_ToggleMenu()
    if not IsValid(SS_ShopMenu) then
        SS_ShopMenu = vgui.Create('DPointShopMenu')
        SS_ShopMenu:SetVisible(false)
    end

    if SS_ShopMenu:IsVisible() then
        if IsValid(SS_CustomizerPanel) then
            SS_CustomizerPanel:Close()
        end

        SS_ShopMenu:Hide()
        gui.EnableScreenClicker(false)
    else
        SS_ShopMenu:Show()
        gui.EnableScreenClicker(true)
    end
end

--[[
function PS:SetHoverItem(item_id)
	local ITEM = PS.Items[item_id]
	
	if ITEM.Model then
		self.HoverModel = item_id
	
		self.HoverModelClientsideModel = ClientsideModel(ITEM.Model, RENDERGROUP_OPAQUE)
		self.HoverModelClientsideModel:SetNoDraw(true)
	end
end

function PS:RemoveHoverItem()
	self.HoverModel = nil
	self.HoverModelClientsideModel = nil
end ]]
--[[
function PS:ShowColorChooser(item, modifications)
	-- TODO: Do this
	local chooser = vgui.Create('DPointShopColorChooser')
	chooser:SetColor(modifications.color)
	
	chooser.OnChoose = function(color)
		modifications.color = color
		self:SendModifications(item.ID, modifications)
	end
end

function PS:SendModifications(item_id, modifications)
	net.Start('SS_ModifyItem')
		net.WriteString(item_id)
		net.WriteTable(modifications)
	net.SendToServer()
end ]]
function SetLoadingPlayerProperty(pi, prop, val, callback, calls)
    calls = calls or 50
    local ply = pi == -1 and LocalPlayer() or Entity(pi)

    if IsValid(ply) then
        ply[prop] = val

        if callback then
            callback(ply)
        end
    else
        if calls < 1 then
            print("ERROR loading " .. prop .. " for " .. tostring(pi))
        else
            timer.Simple(0.5, function()
                SetLoadingPlayerProperty(pi, prop, val, callback, calls - 1)
            end)
        end
    end
end

net.Receive('SS_Items', function(length)
    local items = net.ReadTableHD()

    SetLoadingPlayerProperty(-1, "SS_Items", items, function(ply)
        ply.SS_Items = SS_MakeItems(ply, ply.SS_Items)
        SS_ValidInventory = false
    end)
end)

net.Receive('SS_ShownItems', function(length)
    local pi = net.ReadUInt(8)
    local items = net.ReadTableHD()

    SetLoadingPlayerProperty(pi, "SS_ShownItems", items, function(ply)
        ply.SS_ShownItems = SS_MakeItems(ply, ply.SS_ShownItems)
        ply:SS_ClearCSModels()
        ply.SS_PlayermodelModsClean = false
    end)
end)

net.Receive('SS_Pts', function(length)
    SetLoadingPlayerProperty(-1, "SS_Points", net.ReadUInt(32))
end)

net.Receive('SS_Row', function(length)
    SetLoadingPlayerProperty(-1, "SS_Points", net.ReadUInt(32))
    SetLoadingPlayerProperty(-1, "SS_Donation", net.ReadUInt(32))
end)

function SS_BuyProduct(id)
    if not SS_Products[id] then
        LocalPlayerNotify("Unknown product '" .. tostring(id) .. "'. You may need to update your binds.")

        return
    end

    print('To quickbuy this product, run: bind <key> "ps_buy ' .. id .. '"')
    net.Start('SS_BuyProduct')
    net.WriteString(id)
    net.SendToServer()
end

concommand.Add("ps_buy", function(ply, cmd, args)
    if #args < 1 then
        print("usage: ps_buy product")

        return
    end

    -- if they have the wep and the wep is not a single-use e.g. peacekeeper
    if LocalPlayer():HasWeapon(args[1]) and not SS_Products[args[1]]['ammotype'] then
        input.SelectWeapon(LocalPlayer():GetWeapon(args[1]))

        return
    end

    SS_BuyProduct(args[1])
end)

function SS_SellItem(item_id)
    if not LocalPlayer():SS_FindItem(item_id) then return end
    net.Start('SS_SellItem')
    net.WriteUInt(item_id, 32)
    net.SendToServer()
end

function SS_EquipItem(item_id, state)
    if not LocalPlayer():SS_FindItem(item_id) then return end
    net.Start('SS_EquipItem')
    net.WriteUInt(item_id, 32)
    net.WriteBool(state)
    net.SendToServer()
end

concommand.Add("ps_prop_autorefresh", function()
    timer.Create("ppau", 0.05, 0, function()
        LocalPlayer():SS_ClearCSModels()
    end)
end)

function SendPointsCmd(cmd)
    cmd = string.Explode(" ", cmd)
    local fail = true

    if #cmd >= 2 then
        local amt = tonumber(cmd[#cmd])

        if amt ~= nil then
            table.remove(cmd)
            local ply, cnt = PlyCount(string.Implode(" ", cmd))
            fail = false

            if cnt == 0 then
                chat.AddText("[orange]No player found")
            else
                if cnt == 1 then
                    net.Start("SS_TransferPoints")
                    net.WriteEntity(ply)
                    net.WriteInt(amt, 32)
                    net.SendToServer()
                else
                    chat.AddText("[orange]Multiple found")
                end
            end
        end
    end

    if fail then
        chat.AddText("[orange]Usage: !givepoints player amount")
    end
end

--NOMINIFY
net.Receive("LootBoxAnimation", function(len)
    local mdl = net.ReadString()
    local others = net.ReadTable()
    print(mdl)
    PrintTable(others)
    LootBoxAnimation(mdl, mdl, others)
end)

function LootBoxAnimation(mdl, name, othermdls, boxcolor)
    if IsValid(LOOTBOXPANEL) then
        LOOTBOXPANEL:Remove()
    end

    surface.PlaySound("lootbox.ogg")
    local delay = 4
    local size = 600

    LOOTBOXPANEL = vgui("DFrame", function(p)
        p:SetSize(size, size)
        p:Center()
        p:MakePopup()
        p:SetZPos(10000)
        -- p:SetBackgroundBlur(true)
        p:SetTitle("")
        p:ShowCloseButton(false)

        function p:Paint(w, h)
            render.ClearDepth()
            DisableClipping(true)
            draw.BoxShadow(-3000, -3000, 8000, 8000, 1, 0.5)
            DisableClipping(false)
            draw.BoxShadow(150, 150, w - 300, h - 300, 300, 1)
        end

        vgui("Panel", function(p)
            p:Dock(FILL)

            local infopanel = vgui("Panel", function(p)
                vgui("DButton", function(p)
                    p:SetText("Close")

                    function p:DoClick()
                        LOOTBOXPANEL:Remove()
                    end

                    p:DockMargin(200, 10, 200, 10)
                    p:Dock(BOTTOM)
                end)

                vgui("DLabel", function(p)
                    p:SetText(name)
                    p:SetContentAlignment(5)
                    p:Dock(BOTTOM)
                end)

                p:SetTall(100)
                p:Dock(BOTTOM)
            end)

            infopanel:SetVisible(false)

            vgui("DModelPanel", function(p)
                -- p:SetPos(0,0)
                -- p:SetSize(size,size)
                p:Dock(FILL)
                local otheri = 1
                p:SetModel(othermdls[otheri])
                local boxmodel = ClientsideModel("models/Items/ammocrate_smg1.mdl")
                boxmodel:SetNoDraw(true)

                timer.Simple(0.2, function()
                    if not IsValid(boxmodel) then return end
                    local id, dur = boxmodel:LookupSequence("Close") --Open doesn't work???
                    boxmodel:ResetSequence(id)
                    boxmodel:SetPlaybackRate(0.1) -- doesn't work???
                end)

                function p:OnRemove()
                    if IsValid(boxmodel) then
                        boxmodel:Remove()
                    end
                end

                local t1 = CurTime()

                function p:PreDrawModel(ent)
                    boxmodel:SetPos(Vector(0, 0, ((CurTime() - t1) ^ 2) * -40))
                    boxmodel:SetAngles(Angle(0, 90, 0))
                    -- render.ModelM
                    boxmodel:DrawModel()
                end

                local t1 = CurTime()

                function p:LayoutEntity(ent)
                    local min, max = self.Entity:GetRenderBounds()
                    local center, radius = (min + max) / 2, min:Distance(max) / 2

                    if self.Entity.ScaledToModel ~= self.Entity:GetModel() then
                        self.Entity.ScaledToModel = self.Entity:GetModel()
                        self.Entity:SetModelScale(20 / radius)
                        -- self.Entity:InvalidateBoneCache()
                        -- self.Entity:SetupBones()
                        min, max = self.Entity:GetRenderBounds()
                        center, radius = (min + max) / 2, min:Distance(max) / 2
                    end

                    self.Entity:SetPos(self.Entity:GetPos() - self.Entity:LocalToWorld(center))
                    -- self.Entity:SetModelScale(0.5)
                    -- print(radius)
                    -- (radius + 1)
                    self:SetCamPos((60 * Vector(math.cos((CurTime() - t1) * 1.5) * 0.2, 1, 0.2))) --(radius + 1) *
                    self:SetLookAt(Vector(0, 0, 0))
                end

                local rollspeed = 0.3
                local lastarg

                for i = rollspeed, delay, rollspeed do
                    local arg = {}
                    lastarg = arg

                    timer.Simple(i, function()
                        if not IsValid(p) then return end

                        if arg[1] then
                            p:SetModel(mdl)
                            infopanel:SetVisible(true)
                        else
                            otheri = (otheri % (#othermdls)) + 1
                            p:SetModel(othermdls[otheri])
                        end
                    end)
                end

                lastarg[1] = true
            end)
        end)
    end)
end

function CSSWEAPONMODELS()
    local t = {}

    for k, v in pairs(weapons.GetList()) do
        if v.Base == "weapon_csbasegun" then
            table.insert(t, v.WorldModel)
        end
    end

    return t
end