-- Share Setlist window and chat transfer protocol.
local Main = Sinduriel.SongBook3.Windows.Main;
local MainWindowClass = Main.SongBook3Window;
local Helpers = Sinduriel.SongBook3.Windows.Main;
function MainWindowClass:CreateShareSetlistWindow()
    -- Each chat chunk requires a real, deliberate quickslot click.
    self.setlistShareWindow = Turbine.UI.Lotro.Window();
    self.setlistShareWindow:SetText("Share Setlist");
    self.setlistShareWindow:SetSize(Helpers.SongBook3SavedWindowSize("Share", 500, 235, 500, 235));
    self.setlistShareWindow:SetPosition(310, 180);
    self.setlistShareWindow:SetZOrder(195);
    self.setlistShareWindow:SetVisible(false);
    self.shareInstructions = Turbine.UI.Label();
    self.shareInstructions:SetParent(self.setlistShareWindow);
    self.shareInstructions:SetPosition(18, 46);
    self.shareInstructions:SetSize(460, 54);
    self.shareInstructions:SetMultiline(true);
    self.shareInstructions:SetText("Click Send Part for each chunk; it advances automatically after the click. The receiver needs every part to import the setlist, and each chat command requires a click.");
    self.shareProgress = Turbine.UI.Label();
    self.shareProgress:SetParent(self.setlistShareWindow);
    self.shareProgress:SetPosition(18, 110);
    self.shareProgress:SetSize(460, 28);
    self.setlistShareSlot = Turbine.UI.Lotro.Quickslot();
    self.setlistShareSlot:SetParent(self.setlistShareWindow);
    self.setlistShareSlot:SetPosition(30, 189);
    self.setlistShareSlot:SetSize(32, 30);
    self.setlistShareSlot:SetZOrder(100);
    self.setlistShareSlot:SetAllowDrop(false);
    self.setlistShareSlot.DragDrop = function() self:UpdateSetlistShareShortcut(); end;
    -- LOTRO must execute the alias already loaded in the quickslot before it
    -- is replaced. Advance on the next UI update, matching the Lyrics sender.
    self.shareSendUpdateControl = Turbine.UI.Control();
    self.shareSendUpdateState = 0;
    self.shareSendUpdateControl.Update = function(sender, args)
        if self.shareSendUpdateState == 1 then
            self.shareSendUpdateState = 0;
            self:AdvanceSetlistSharePart();
            sender:SetWantsUpdates(false);
        end
    end;
    self.setlistShareSlot.MouseClick = function(sender, args)
        if args.Button ~= Turbine.UI.MouseButton.Left then return; end
        if self.shareSendUpdateState ~= 0 then return; end
        local total = #(self.setlistSendParts or {});
        local index = tonumber(self.setlistSendPartIndex) or 0;
        if index >= 1 and index <= total then
            self.shareSendUpdateState = 1;
            self.shareSendUpdateControl:SetWantsUpdates(true);
        end
    end;
    self.shareSlotButton = Turbine.UI.Control();
    self.shareSlotButton:SetParent(self.setlistShareWindow);
    self.shareSlotButton:SetPosition(30, 189);
    self.shareSlotButton:SetSize(35, 35);
    self.shareSlotButton:SetZOrder(110);
    self.shareSlotButton:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend);
    self.shareSlotButton:SetBackground(gDir .. "icn_send.tga");
    self.shareSlotButton:SetMouseVisible(false);
    self.shareSlotText = Turbine.UI.Label();
    self.shareSlotText:SetParent(self.setlistShareWindow);
    self.shareSlotText:SetPosition(70, 191);
    self.shareSlotText:SetSize(100, 35);
    self.shareSlotText:SetMultiline(true);
    self.shareSlotText:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
    self.shareSlotText:SetText("Send Part");
    self.shareSlotText:SetMouseVisible(false);
    self.setlistShareSlot.MouseEnter = function()
        self.shareSlotButton:SetBackground(gDir .. "icn_send_hover.tga");
    end;
    self.setlistShareSlot.MouseLeave = function()
        self.shareSlotButton:SetBackground(gDir .. "icn_send.tga");
    end;
    self.setlistShareSlot.MouseDown = function()
        self.shareSlotButton:SetBackground(gDir .. "icn_send_down.tga");
    end;
    self.setlistShareSlot.MouseUp = function()
        self.shareSlotButton:SetBackground(gDir .. "icn_send_hover.tga");
    end;
    local shareClose = Turbine.UI.Lotro.Button();
    shareClose:SetParent(self.setlistShareWindow);
    shareClose:SetPosition(336, 195);
    shareClose:SetSize(140, 26);
    shareClose:SetText("Close");
    shareClose.MouseClick = function() self.setlistShareWindow:SetVisible(false); end;
    self.shareCloseButton = shareClose;
    self.shareResize = Helpers.SongBook3AttachResizeGrip(self.setlistShareWindow, 500, 235,
        function() self:LayoutShareSetlistWindow(); end,
        function() self:SaveSettings(); end);
    self:LayoutShareSetlistWindow();

end

function MainWindowClass:LayoutShareSetlistWindow()
    if not self.setlistShareWindow or not self.setlistShareSlot then return; end
    local width, height = self.setlistShareWindow:GetSize();
    self.shareInstructions:SetPosition(18, 46);
    self.shareInstructions:SetSize(width - 36, height - 171);
    self.shareProgress:SetPosition(18, height - 125);
    self.shareProgress:SetSize(width - 36, 28);
    self.setlistShareSlot:SetPosition(30, height - 46);
    self.shareSlotButton:SetPosition(30, height - 46);
    self.shareSlotText:SetPosition(70, height - 46);
    self.shareCloseButton:SetPosition(width - 164, height - 40);
end
-- Choose the normal group channel, not user-defined channels where outsiders
-- can send a signal. Raid overrides fellowship when explicitly selected.
function MainWindowClass:SetlistShareChannel()
    if self.UseRaidChat or Main.GroupIsRaid == 1 then return "/ra"; end
    local party = self.playerInstance and self.playerInstance:GetParty();
    if party and party:GetMemberCount() > 6 then return "/ra"; end
    return "/f";
end

function MainWindowClass:BeginSetlistShare()
    -- Cancel any deferred advance from a previous transfer before starting over.
    self.shareSendUpdateState = 0;
    if self.shareSendUpdateControl then
        self.shareSendUpdateControl:SetWantsUpdates(false);
    end
    local songs = self.setlistData.lists[self.activeSetlist] or {};
    if #songs == 0 then
        self.setlistNote:SetText("Add Songs Before Sharing The Setlist.");
        return;
    end
    if #songs > 200 then
        self.setlistNote:SetText("Setlist Too Large To Share (200 Song Limit).");
        return;
    end
    local encoded = {Helpers.SongBook3EncodePath(self.activeSetlist)};
    for i, path in ipairs(songs) do encoded[#encoded + 1] = Helpers.SongBook3EncodePath(path); end
    local data = table.concat(encoded, "~");
    if #data > 26000 then
        self.setlistNote:SetText("Setlist Too Large For Chat Transfer.");
        return;
    end
    local count = math.ceil(#data / 130);
    local id = Helpers.SongBook3PathHash(self.activeSetlist .. data .. tostring(Turbine.Engine.GetLocalTime()));
    self.setlistSendParts = {};
    for i = 1, count do
        self.setlistSendParts[i] = "[SB2LIST|" .. id .. "|" .. i .. "|" .. count .. "|" ..
            string.sub(data, (i-1)*130+1, i*130) .. "]";
    end
    self.setlistSendPartIndex = 1;
    self:UpdateSetlistShareShortcut();
    self.setlistShareWindow:SetVisible(true);
    self.setlistShareWindow:Activate();
end

function MainWindowClass:AdvanceSetlistSharePart()
    local total = #(self.setlistSendParts or {});
    local index = tonumber(self.setlistSendPartIndex) or 1;
    if index < 1 or index > total then return false; end
    self.setlistSendPartIndex = index + 1;
    self:UpdateSetlistShareShortcut();
    return true;
end

function MainWindowClass:UpdateSetlistShareShortcut()
    local index = self.setlistSendPartIndex or 1;
    local chunks = self.setlistSendParts or {};
    local total = #chunks;
    if index > total or total == 0 then
        self.setlistShareSlot:SetShortcut(Turbine.UI.Lotro.Shortcut(
            Turbine.UI.Lotro.ShortcutType.Undefined, ""));
        self.setlistShareSlot:SetVisible(false);
        self.shareSlotButton:SetVisible(false);
        self.shareSlotText:SetVisible(false);
        self.shareProgress:SetText("All Parts Sent. Receiver Can Import Once All Parts Arrive.");
        return;
    end
    self.setlistShareSlot:SetShortcut(Turbine.UI.Lotro.Shortcut(
        Turbine.UI.Lotro.ShortcutType.Alias,
        self:SetlistShareChannel() .. " " .. chunks[index]));
    self.setlistShareSlot:SetVisible(true);
    self.shareSlotButton:SetVisible(true);
    self.shareSlotText:SetVisible(true);
    self.shareSlotText:SetText("Send Part\n" .. index .. " / " .. total);
    self:EnsureChatListener();
    self.shareProgress:SetText("Ready To Send Part " .. index .. " Of " .. total .. ".");
end

function MainWindowClass:ReceiveSetlistChunk(from, message)
    local id, seqText, countText, fragment = string.match(message,
        "%[SB2LIST|(%x+)|(%d+)|(%d+)|([^%]]+)%]");
    if not id or type(from) ~= "string" or from == "" then return; end
    local seq, count = tonumber(seqText), tonumber(countText);
    if not seq or not count or count < 1 or count > 200 or seq < 1 or seq > count
       or #fragment > 130 then return; end
    local key = from .. ":" .. id;
    local sessions = self.incomingSetlists;
    local session = sessions[key];
    if not session then
        local n = 0;
        for k in pairs(sessions) do n = n + 1; end
        if n >= 8 then self.incomingSetlists = {}; sessions = self.incomingSetlists; end
        session = { chunks = {}, count = count, received = 0, sender = from };
        sessions[key] = session;
    end
    if session.count ~= count then return; end
    if not session.chunks[seq] then
        session.chunks[seq] = fragment;
        session.received = session.received + 1;
    end
    if session.received ~= count then return; end
    sessions[key] = nil;
    local encoded = table.concat(session.chunks);
    if #encoded > 26000 then return; end
    local fields = {};
    for element in string.gmatch(encoded .. "~", "(.-)~") do
        fields[#fields + 1] = Helpers.SongBook3DecodePath(element);
        if #fields > 201 then return; end
    end
    local name = fields[1];
    if not name or name == "" or #fields < 2 then return; end
    local paths = {};
    for i = 2, #fields do
        if fields[i] == "" or #fields[i] > 500 then return; end
        paths[#paths + 1] = fields[i];
    end
    self.pendingReceivedSetlist = {
        name = string.sub(name, 1, 55), songs = paths, sender = from,
    };
    self.receivedSetlistLabel:SetText("From: " .. from .. "\n" ..
        "Setlist: " .. name .. " (" .. #paths .. " Songs)\n" ..
        "Import As A New Saved Setlist?");
    self.receivedSetlistWindow:SetVisible(true);
    self.receivedSetlistWindow:Activate();
end

