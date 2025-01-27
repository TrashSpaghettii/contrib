﻿local THUMB = {}
AccessorFunc(THUMB, "m_sImgur", "Imgur", FORCE_STRING)

function THUMB:Init()
    self.BaseClass.Init(self)
    self:SetText("")
    self:SetSize(64, 64)
end

function THUMB:SetImgur(id)
    assert(isstring(id), "Expected string, got" .. type(id))
    self.m_sImgur = id
    self:SetText(id ~= "" and "" or "None")
end

function THUMB:Paint(w, h)
    if (self:GetImgur() ~= "") then
        local m = WebMaterial({
            id = self:GetImgur(),
            shader = "UnlitGeneric"
        })

        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(m)
        surface.DrawTexturedRect(4, 4, w - 8, h - 8)
    end
end

vgui.Register('DImgurThumbnail', THUMB, 'DButton')

--generalized list of imgur materials
function DImgurThumbnail(url, nsfw, size)
    local panel = vgui.Create("DImgurThumbnail")
    panel:SetImgur(url)

    return panel
end

local CONTENTPICKER = {}
AccessorFunc(CONTENTPICKER, "m_iColumns", "Columns", FORCE_NUMBER)

function CONTENTPICKER:Init()
    self.Scroll = vgui.Create("DScrollPanel", self)
    self.Scroll:Dock(FILL)
    self.Scroll.Paint = noop()
    self.Bottom = vgui.Create("DPanel", self)
    self.Bottom:Dock(TOP)
    self.Bottom:DockMargin(SS_COMMONMARGIN, SS_COMMONMARGIN, SS_COMMONMARGIN, SS_COMMONMARGIN)
    self.Bottom.Paint = SS_PaintBG
    self.AddField = vgui.Create("DTextEntry", self.Bottom)
    self.AddField:Dock(FILL)
    self.AddField:SetPaintBackground(false)
    self.AddField:SetUpdateOnType(true)
    self.AddField:SetTextColor(MenuTheme_TX)

    self.AddField.UpdateColours = function(pnl)
        pnl:SetTextColor(MenuTheme_TX)
        pnl:SetCursorColor(MenuTheme_TX)
    end

    self.AddField.OnValueChange = function(textself, new) end
    self.AddButton = vgui.Create("DButton", self.Bottom)
    self.AddButton:SetSize(64, 16)
    self.AddButton:SetText("Save To List")
    self.AddButton:DockMargin(4, 4, 4, 4)
    self.AddButton:Dock(RIGHT)
    self.AddButton.Paint = SS_PaintButtonBrandHL
    local textentry = self.AddField

    self.AddButton.DoClick = function(btn)
        if (self.AddField:GetText() == "") then return end
        local img = self.AddField:GetText()

        AsyncSanitizeImgurId(img, function(id)
            if id == nil then
                local prevtext = img .. ""
                textentry:SetText("BAD URL")
                textentry:SetTextColor(Color(255, 0, 0, 255))

                timer.Simple(1, function()
                    if (IsValid(textentry)) then
                        textentry:SetTextColor(MenuTheme_TX)

                        if (textentry:GetText() == "BAD URL") then
                            textentry:SetText(prevtext)
                        end
                    end
                end)

                return
            end

            self:AddPermanent(id, false)
            textentry:SetText(id)
        end)
    end

    SS_SetupVBar(self.Scroll.VBar)
    self.Tiles = vgui.Create("DIconLayout", self.Scroll)
    self.Tiles:Dock(FILL)
    self.Tiles:DockMargin(0, 0, SS_COMMONMARGIN, 0)
    self.Tiles.Paint = noop
    local oll = self.Tiles.PerformLayout

    self.Tiles.PerformLayout = function(pnl)
        oll(pnl)
        pnl:SizeToChildren(false, true)
        pnl:DockMargin(0, 0, self.Scroll.VBar:IsVisible() and SS_COMMONMARGIN or 0, 0)
    end

    self:SetColumns(self.m_iColumns or 5)
end

function CONTENTPICKER:PerformLayout(w, h)
    local height = 0
    local l, u, r, d = self.Tiles:GetDockMargin()
    height = height + self.Tiles:GetTall() + u + d

    if (IsValid(self.Bottom)) then
        local l, u, r, d = self.Bottom:GetDockMargin()
        height = height + self.Bottom:GetTall() + u + d
    end

    self:SetTall(height)
    --self.Tiles:InvalidateLayout(true)
    --self.Scroll:InvalidateLayout(true)
    local col = self:GetColumns() or 5
    local space = w

    if (self.Scroll.VBar:IsVisible()) then
        space = space - self.Scroll.VBar:GetWide()
        local l, t, r, b = self.Scroll:GetDockMargin()
        space = space - l - r
        local l, t, r, b = self.Tiles:GetDockMargin()
        space = space - l - r
        space = space - 1
    end

    local divsize = space / col

    for k, v in pairs(self.Tiles:GetChildren()) do
        v:SetSize(divsize, divsize)
    end

    if (IsValid(self.Bottom)) then
        self.Bottom:AlignRight(4)
        self.Bottom:CenterVertical()
    end
end

--SS_PaintBG(self,w,h) 
function CONTENTPICKER:Paint(w, h)
    SS_PaintFG(self, w, h)
end

function CONTENTPICKER:Reload()
    for k, v in pairs(self.Tiles:GetChildren()) do
        v:Remove()
    end

    for k, v in pairs(self.Images) do
        self:Add(v.url)
    end
end

function CONTENTPICKER:Load(slist)
    slist = slist or "default"
    self.SaveList = slist
    local tbl = util.JSONToTable(file.Read("swampshop_textures/" .. slist .. ".txt") or "") or {}
    self.Images = {}

    for k, v in pairs(tbl) do
        table.insert(self.Images, {
            url = tostring(v.url),
        })
    end

    self:Reload()
end

function CONTENTPICKER:Save()
    local slist = self.SaveList or "default"
    local tbl = self.Images
    file.CreateDir("swampshop_textures")
    file.Write("swampshop_textures/" .. slist .. ".txt", util.TableToJSON(tbl))
end

function CONTENTPICKER:Add(url, nsfw)
    local dont

    for k, v in pairs(self.Tiles:GetChildren()) do
        if (v:GetImgur() == url) then
            dont = true
        end
    end

    if dont then return end
    local tile = self.Tiles:Add(DImgurThumbnail(url))
    self:InvalidateLayout(true)
    self:InvalidateParent(true)

    tile.DoClick = function(pnl)
        self:OnChoose(tile:GetImgur())
    end

    tile.DoRightClick = function(pnl) end
end

function CONTENTPICKER:AddPermanent(url)
    local dont

    for k, v in pairs(self.Images) do
        if v.url == url then
            self.Images[k] = {
                url = url
            }
        end
    end

    if dont then
        self:Save()

        return
    end

    table.insert(self.Images, {
        url = url
    })

    self:Save()
    self:Add(url)
end

function CONTENTPICKER:OnChoose(url)
end

vgui.Register('DImgurManager', CONTENTPICKER, 'DPanel')

concommand.Add("imgurtest", function()
    local wind = vgui.Create("DFrame")
    wind:SetSize(512 + 10, 512 + 12)
    wind:Center()
    wind:SetSizable(true)
    wind:MakePopup()

    local manager = vgui("DImgurManager", wind, function(p)
        p:Dock(FILL)
    end)

    manager:SetColumns(5)

    for i = 1, 32 do
        manager:Add(math.random(0, 1) == 1 and "yWPiba1.png" or "XNmSNPo.png", false)
    end
end)
