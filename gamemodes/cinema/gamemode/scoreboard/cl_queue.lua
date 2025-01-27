﻿-- This file is subject to copyright - contact swampservers@gmail.com for more information.
-- INSTALL: CINEMA
surface.CreateFont("ScoreboardVidTitle", {
    font = "Open Sans Condensed",
    size = 20,
    weight = 200
})

surface.CreateFont("ScoreboardVidDuration", {
    font = "Open Sans",
    size = 14,
    weight = 200
})

surface.CreateFont("ScoreboardVidVotes", {
    font = "Open Sans Condensed",
    size = 18,
    weight = 200
})

local QUEUE = {}
QUEUE.TitleHeight = 64
QUEUE.VidHeight = 32 -- 48

function QUEUE:Init()
    self:SetZPos(1)
    self:SetSize(288, 512)
    self:SetPos(8, ScrH() / 2 - (self:GetTall() / 2))
    self.Title = Label(T'Queue_Title', self)
    self.Title:SetFont("ScoreboardTitle")
    self.Title:SetColor(Color(255, 255, 255))
    self.Videos = {}
    self.NextUpdate = 0.0
    self.VideoList = vgui.Create("TheaterList", self)
    self.VideoList:DockMargin(0, self.TitleHeight + 2, 0, 0)
    self.Options = vgui.Create("DPanelList", self)
    self.Options:SetDrawBackground(false)
    self.Options:SetPadding(4)
    self.Options:SetSpacing(4)
    -- Theater Options
    local RequestButton = vgui.Create("TheaterButton")
    RequestButton:SetText(T'Request_Video')

    RequestButton.DoClick = function(self)
        local RequestFrame = vgui.Create("VideoRequestFrame")

        if IsValid(RequestFrame) then
            RequestFrame:Center()
            RequestFrame:MakePopup()
        end
    end

    self.Options:AddItem(RequestButton)
    local LastRequestButton = vgui.Create("TheaterButton")
    LastRequestButton:SetText('Last Video in History')

    LastRequestButton.DoClick = function(self)
        RunConsoleCommand("cinema_requestlast")
    end

    self.Options:AddItem(LastRequestButton)
    local VoteSkipButton = vgui.Create("TheaterButton")
    VoteSkipButton:SetText(T'Vote_Skip')

    VoteSkipButton.DoClick = function(self)
        RunConsoleCommand("cinema_voteskip")
    end

    self.Options:AddItem(VoteSkipButton)
    local FullscreenButton = vgui.Create("TheaterButton")
    FullscreenButton:SetText('Toggle Fullscreen/Clicker')

    FullscreenButton.DoClick = function(self)
        RunConsoleCommand("cinema_fullscreen")
    end

    self.Options:AddItem(FullscreenButton)
    local RefreshButton = vgui.Create("TheaterButton")
    RefreshButton:SetText(T'Refresh_Theater')

    RefreshButton.DoClick = function(self)
        RunConsoleCommand("cinema_refresh")
    end

    self.Options:AddItem(RefreshButton)
end

function QUEUE:AddVideo(vid)
    if self.Videos[vid.id] then
        self.Videos[vid.id]:SetVideo(vid)
    else
        local panel = vgui.Create("ScoreboardVideo", self)
        panel:SetVideo(vid)
        panel:SetVisible(true)
        self.Videos[vid.id] = panel
        self.VideoList:AddItem(panel)
    end
end

function QUEUE:RemoveVideo(vid)
    if ValidPanel(self.Videos[vid.id]) then
        self.VideoList:RemoveItem(self.Videos[vid.id])
        self.Videos[vid.id]:Remove()
        self.Videos[vid.id] = nil
    end
end

function QUEUE:Update()
    local Theater = Me:GetTheater()
    if not Theater then return end
    theater.PollServer()
end

function QUEUE:UpdateList()
    local ids = {}

    for _, vid in pairs(theater.GetQueue()) do
        self:AddVideo(vid)
        ids[vid.id] = true
    end

    for k, panel in pairs(self.Videos) do
        if not ids[k] then
            self:RemoveVideo(panel.Video)
        end
    end

    self.VideoList:SortVideos(function(a, b)
        if a.vto == b.vto then
            return a.rt < b.rt
        else
            return a.vto > b.vto
        end
    end)
end

function QUEUE:Think()
    if RealTime() > self.NextUpdate then
        self:Update()
        self:InvalidateLayout()
        self.NextUpdate = RealTime() + 0.4
    end
end

function QUEUE:Paint(w, h)
    surface.SetDrawColor(BrandColorGrayDarker)
    surface.DrawRect(0, 0, self:GetWide(), self:GetTall())
    local xp, _ = self:GetPos()
    BrandBackgroundPattern(0, 0, self:GetWide(), self.Title:GetTall(), xp)
    BrandDropDownGradient(0, self.Title:GetTall(), self:GetWide())
end

function QUEUE:PerformLayout()
    self.Title:SizeToContents()
    self.Title:SetTall(self.TitleHeight)
    self.Title:CenterHorizontal()

    if self.Title:GetWide() > self:GetWide() and self.Title:GetFont() ~= "ScoreboardTitleSmall" then
        self.Title:SetFont("ScoreboardTitleSmall")
    end

    self.VideoList:Dock(FILL)
    self.Options:Dock(BOTTOM)
    self.Options:SizeToContents()
end

vgui.Register("ScoreboardQueue", QUEUE)
local VIDEO = {}
VIDEO.Padding = 8

function VIDEO:Init()
    self:SetTall(QUEUE.VidHeight)
    self.Title = Label("Unknown", self)
    self.Title:SetFont("ScoreboardVidTitle")
    self.Title:SetColor(Color(255, 255, 255))
    self.Duration = Label("0:00/0:00", self)
    self.Duration:SetFont("ScoreboardVidDuration")
    self.Duration:SetColor(Color(255, 255, 255))
    self.Controls = vgui.Create("ScoreboardVideoVote", self)
end

function VIDEO:Update()
    self.Title:SetText(self.Video.ttl)
    self:SetTooltip(self.Video.ttl)
    self.Duration:SetText(string.FormatSeconds(self.Video.dur))
    self.Controls:Update()
end

function VIDEO:SetVideo(vid)
    self.Video = vid
    self.Controls:SetVideo(vid)
    self:Update()
end

function VIDEO:PerformLayout()
    self.Controls:SizeToContents()
    self.Controls:CenterVertical()
    self.Controls:AlignRight(self.Padding)
    local x, y = self.Controls:GetPos()
    self.Title:SizeToContents()
    local w = self.Title:GetWide()
    w = math.Clamp(w, 0, x - self.Padding * 2)
    self.Title:SetSize(w, self.Title:GetTall())
    self.Title:AlignTop(-2)
    self.Title:AlignLeft(self.Padding)
    self.Duration:SizeToContents()
    self.Duration:AlignTop(self.Title:GetTall() - 4)
    self.Duration:AlignLeft(self.Padding)
end

function VIDEO:Paint(w, h)
    surface.SetDrawColor(BrandColorGrayDark)
    surface.DrawRect(0, 0, self:GetSize())
end

vgui.Register("ScoreboardVideo", VIDEO)
local VIDEOVOTE = {}
VIDEOVOTE.Padding = 8

function IsMouseOver(self)
    local x, y = self:CursorPos()

    return x >= 0 and y >= 0 and x <= self:GetWide() and y <= self:GetTall()
end

function VIDEOVOTE:Init()
    self.Votes = Label("+99", self)
    self.Votes:SetFont("ScoreboardVidVotes")
    self.Votes:SetColor(Color(255, 255, 255))
    self.VoteUp = vgui.Create("DImageButton", self)
    self.VoteUp:SetSize(16, 16)
    self.VoteUp:SetImage("theater/up.png")

    self.VoteUp.DoClick = function()
        local last = self.Video.vlo
        self.Video.vlo = (last ~= 1) and 1
        self.Video.vto = self.Video.vto + (self.Video.vlo or 0) - (last or 0)
        RunConsoleCommand("cinema_vote", self.Video.id, self.Video.vlo or 0)
        self:Update()
        self.vlo_hold = RealTime() + 1
    end

    self.VoteUp.Think = function()
        if IsMouseOver(self.VoteUp) or self.VoteUp.Voted then
            self.VoteUp:SetAlpha(255)
        else
            self.VoteUp:SetAlpha(25)
        end
    end

    self.VoteDown = vgui.Create("DImageButton", self)
    self.VoteDown:SetSize(16, 16)
    self.VoteDown:SetImage("theater/down.png")

    self.VoteDown.DoClick = function()
        local last = self.Video.vlo
        self.Video.vlo = (last ~= -1) and -1
        self.Video.vto = self.Video.vto + (self.Video.vlo or 0) - (last or 0)
        RunConsoleCommand("cinema_vote", self.Video.id, self.Video.vlo or 0)
        self:Update()
        self.vlo_hold = RealTime() + 1
    end

    self.VoteDown.Think = function()
        if IsMouseOver(self.VoteDown) or self.VoteDown.Voted then
            self.VoteDown:SetAlpha(255)
        else
            self.VoteDown:SetAlpha(25)
        end
    end
end

function VIDEOVOTE:AddRemoveButton()
    if ValidPanel(self.RemoveBtn) then return end
    self.RemoveBtn = vgui.Create("DImageButton", self)
    self.RemoveBtn:SetSize(16, 16)
    self.RemoveBtn:SetImage("theater/trashbin.png")

    self.RemoveBtn.DoClick = function()
        RunConsoleCommand("cinema_video_remove", self.Video.id)

        if ValidPanel(GuiQueue) then
            GuiQueue:RemoveVideo(self.Video)
        end
    end

    self.RemoveBtn.Think = function()
        if IsMouseOver(self.RemoveBtn) or self.RemoveBtn.Voted then
            self.RemoveBtn:SetAlpha(255)
            self.RemoveBtn:SetColor(Color(255, 0, 0))
        else
            self.RemoveBtn:SetAlpha(25)
            self.RemoveBtn:SetColor(Color(255, 255, 255))
        end
    end
end

function VIDEOVOTE:Vote(up)
    if up then
        self.VoteUp:SetColor(Color(0, 255, 0))
        self.VoteUp.Voted = true
        self.VoteDown:SetColor(Color(255, 255, 255))
        self.VoteDown.Voted = nil
    elseif up == false then
        self.VoteUp:SetColor(Color(255, 255, 255))
        self.VoteUp.Voted = nil
        self.VoteDown:SetColor(Color(255, 0, 0))
        self.VoteDown.Voted = true
    else
        self.VoteUp:SetColor(Color(255, 255, 255))
        self.VoteUp.Voted = nil
        self.VoteDown:SetColor(Color(255, 255, 255))
        self.VoteDown.Voted = nil
    end
end

function VIDEOVOTE:Update()
    if not self.Video then return end
    local prefix = (self.Video.vto > 0) and "+" or ""
    self.Votes:SetText(prefix .. self.Video.vto)

    if self.Video.vlo == 1 then
        self:Vote(true)
    elseif self.Video.vlo == -1 then
        self:Vote(false)
    else
        self:Vote(nil)
    end

    local Theater = Me:GetTheater()

    if self.Video.own or Me:StaffControlTheater() or (Theater and Theater:IsPrivate() and Theater:GetOwner() == Me) then
        self:AddRemoveButton()
        self:SetWide(84)
    else
        self:SetWide(64)
    end
end

function VIDEOVOTE:SetVideo(vid)
    --keeps network delay from overwriting us
    if self.Video and (self.vlo_hold or 0) > RealTime() then
        local off = (self.Video.vlo or 0) - (vid.vlo or 0)
        vid.vto = vid.vto + off
        vid.vlo = self.Video.vlo
    end

    self.Video = vid
    self:Update()
end

function VIDEOVOTE:PerformLayout()
    self.VoteUp:Center()
    self.VoteUp:AlignLeft()
    self.Votes:SizeToContents()

    if self.RemoveBtn then
        self.VoteDown:Center()
        self.VoteDown:AlignRight(24)
        self.Votes:Center()
        local x, y = self.Votes:GetPos()
        self.Votes:AlignLeft(x - 12)
        self.RemoveBtn:Center()
        self.RemoveBtn:AlignRight()
    else
        self.VoteDown:Center()
        self.VoteDown:AlignRight()
        self.Votes:Center()
    end
end

vgui.Register("ScoreboardVideoVote", VIDEOVOTE)
