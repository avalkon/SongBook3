-- Sync Check - player/instrument status report.
local Main = Sinduriel.SongBook3.Windows.Main;
local MainWindowClass = Main.SongBook3Window;
local Helpers = Sinduriel.SongBook3.Windows.Main;
local function SongBook3SyncLineWidth(text, viewportWidth)
    return math.max(viewportWidth - 4, math.min(4096, #(text or "") * 8 + 22));
end

function MainWindowClass:CreateSyncCheckWindow()
    self.readyCheckBtn = Turbine.UI.Lotro.Button();
    self.readyCheckBtn:SetParent(self);
    self.readyCheckBtn:SetSize(110, 20);
    self.readyCheckBtn:SetText("Sync Check");
    self.readyCheckBtn.MouseClick = function() self:ShowReadyCheck(false); end;
    self.readyCheckWindow = Turbine.UI.Lotro.Window();
    self.readyCheckWindow:SetText("Sync Check");
    self.readyCheckWindow:SetSize(Helpers.SongBook3SavedWindowSize("SyncCheck", 505, 376, 505, 320));
    self.readyCheckWindow:SetPosition(300, 145);
    self.readyCheckWindow:SetVisible(false);
    self.readyCheckWindow:SetZOrder(190);
    self.readySummary = Turbine.UI.Label();
    self.readySummary:SetParent(self.readyCheckWindow);
    self.readySummary:SetPosition(18, 43);
    self.readySummary:SetSize(468, 55);
    self.readySummary:SetMultiline(true);
    self.readyIssues = Turbine.UI.ListBox();
    self.readyIssues:SetParent(self.readyCheckWindow);
    self.readyIssues:SetPosition(18, 101);
    self.readyIssues:SetSize(469, 211);
    self.readyScroll = Turbine.UI.Lotro.ScrollBar();
    self.readyScroll:SetParent(self.readyCheckWindow);
    self.readyScroll:SetPosition(487, 101);
    self.readyScroll:SetSize(10, 211);
    self.readyScroll:SetOrientation(Turbine.UI.Orientation.Vertical);
    self.readyIssues:SetVerticalScrollBar(self.readyScroll);
    self.readyHScroll = Turbine.UI.Lotro.ScrollBar();
    self.readyHScroll:SetParent(self.readyCheckWindow);
    self.readyHScroll:SetOrientation(Turbine.UI.Orientation.Horizontal);
    self.readyHScroll:SetPosition(18, 312);
    self.readyHScroll:SetSize(469, 13);
    self.readyIssues:SetHorizontalScrollBar(self.readyHScroll);
    self.readyRefresh = Turbine.UI.Lotro.Button();
    self.readyRefresh:SetParent(self.readyCheckWindow);
    self.readyRefresh:SetPosition(18, 338);
    self.readyRefresh:SetSize(146, 26);
    self.readyRefresh:SetText("Refresh Check");
    self.readyRefresh.MouseClick = function() self:RefreshReadyCheck(); end;

    self.readyStartSlot = Turbine.UI.Lotro.Quickslot();
    self.readyStartSlot:SetParent(self.readyCheckWindow);
    self.readyStartSlot:SetPosition(194, 330);
    self.readyStartSlot:SetSize(32, 30);
    self.readyStartSlot:SetZOrder(100);
    self.readyStartSlot:SetAllowDrop(false);
    self.readyStartShortcut = Turbine.UI.Lotro.Shortcut(
        Turbine.UI.Lotro.ShortcutType.Alias, Strings["cmd_start"]);
    self.readyStartSlot:SetShortcut(self.readyStartShortcut);
    self.readyStartSlot.DragDrop = function()
        self.readyStartSlot:SetShortcut(self.readyStartShortcut);
    end;
    self.readyStartSlot.MouseClick = function(sender, args)
        if args.Button == Turbine.UI.MouseButton.Left then
            self.readyCheckWindow:SetVisible(false);
        end
    end;
    self.readyStartButton = Turbine.UI.Control();
    self.readyStartButton:SetParent(self.readyCheckWindow);
    self.readyStartButton:SetPosition(194, 330);
    self.readyStartButton:SetSize(35, 35);
    self.readyStartButton:SetZOrder(110);
    self.readyStartButton:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend);
    self.readyStartButton:SetBackground(gDir .. "icn_ss.tga");
    self.readyStartButton:SetMouseVisible(false);
    self.readyStartText = Turbine.UI.Label();
    self.readyStartText:SetParent(self.readyCheckWindow);
    self.readyStartText:SetPosition(236, 333);
    self.readyStartText:SetSize(92, 27);
    self.readyStartText:SetText("Start Song");
    self.readyStartText:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
    self.readyStartText:SetMouseVisible(false);
    self.readyStartSlot.MouseEnter = function()
        self.readyStartButton:SetBackground(gDir .. "icn_ss_hover.tga");
    end;
    self.readyStartSlot.MouseLeave = function()
        self.readyStartButton:SetBackground(gDir .. "icn_ss.tga");
    end;
    self.readyStartSlot.MouseDown = function()
        self.readyStartButton:SetBackground(gDir .. "icn_ss_down.tga");
    end;
    self.readyStartSlot.MouseUp = function()
        self.readyStartButton:SetBackground(gDir .. "icn_ss_hover.tga");
    end;
    self.readyCancel = Turbine.UI.Lotro.Button();
    self.readyCancel:SetParent(self.readyCheckWindow);
    self.readyCancel:SetPosition(332, 338);
    self.readyCancel:SetSize(146, 26);
    self.readyCancel:SetText("Cancel");
    self.readyCancel.MouseClick = function() self.readyCheckWindow:SetVisible(false); end;
    self.readyResize = Helpers.SongBook3AttachResizeGrip(self.readyCheckWindow, 505, 320,
        function() self:LayoutSyncCheckWindow(); end,
        function() self:SaveSettings(); end);
    self:LayoutSyncCheckWindow();

end

function MainWindowClass:LayoutSyncCheckWindow()
    if not self.readyCheckWindow or not self.readyIssues then return; end
    local width, height = self.readyCheckWindow:GetSize();
    self.readySummary:SetPosition(18, 43);
    self.readySummary:SetSize(width - 36, 55);
    local listLeft = 18;
    local scrollbarWidth = 10;
    local rightInset = 8;
    local scrollbarX = width - rightInset - scrollbarWidth;
    local listWidth = scrollbarX - listLeft;
    local listHeight = height - 165;
    self.readyIssues:SetPosition(listLeft, 101);
    self.readyIssues:SetSize(listWidth, listHeight);
    self.readyScroll:SetPosition(scrollbarX, 101);
    self.readyScroll:SetSize(scrollbarWidth, listHeight);
    self.readyHScroll:SetPosition(listLeft, 101 + listHeight);
    self.readyHScroll:SetSize(listWidth, 13);
    for i = 1, self.readyIssues:GetItemCount() do
        local item = self.readyIssues:GetItem(i);
        if item then
            item:SetSize(SongBook3SyncLineWidth(item:GetText(), listWidth), 22);
        end
    end
    self.readyRefresh:SetPosition(18, height - 38);
    local slotX = math.floor(width / 2) - 59;
    self.readyStartSlot:SetPosition(slotX, height - 46);
    self.readyStartButton:SetPosition(slotX, height - 46);
    self.readyStartText:SetPosition(slotX + 42, height - 43);
    self.readyCancel:SetPosition(width - 173, height - 38);
end
function MainWindowClass:RefreshReadyCheck()
    if not self.readyIssues then return; end
    self.readyIssues:ClearItems();
    local song = Main.SongDB.Songs[Main.selectedSongIndex];
    if not song or not song.Tracks then
        self.readySummary:SetText("Select A Song First.");
        self.readyStartSlot:SetVisible(false);
        self.readyStartButton:SetVisible(false);
        self.readyStartText:SetVisible(false);
        return 1;
    end
    self.readyStartSlot:SetVisible(true);
    self.readyStartButton:SetVisible(true);
    self.readyStartText:SetVisible(true);
    local ready, optional, conflicts = 0, 0, 0;
    local function AddLine(text, state)
        local item = Turbine.UI.Label();
        item:SetSize(SongBook3SyncLineWidth(text, self.readyIssues:GetWidth()), 22);
        item:SetMultiline(false);
        item:SetText(text);
        item:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
        if state == "conflict" then
            item:SetForeColor(self.colourWrongInstrument);
        elseif state == "ready" then
            item:SetForeColor(self.colourDefaultHighlighted);
        else
            item:SetForeColor(self.colourDefault);
        end
        self.readyIssues:AddItem(item);
    end
    for i, track in ipairs(song.Tracks) do
        if not self.iCurrentSetup or self.aSetupListIndices[i] then
            local state = self:GetTrackReadyState(Main.selectedSongIndex, i);
            local good = state[4] or 0;
            local wrong = state[7] or 0;
            local synced = state[8] or 0;
            local reason = nil;
            -- A synced/highlighted part is ready, even if /play sync did not
            -- also generate the newer explicit "ready" group-chat status.
            -- Mirror the original track coloring/ready state, including
            -- locally synced wrong instruments (states 3 and 6).
            local originalState = state[0];
            if wrong > 0 or originalState == 3 or originalState == 4 or
               originalState == 5 or originalState == 6 then
                reason = "Wrong Instrument";
            elseif good > 1 or synced > 1 or originalState == 0 or originalState == 2 then
                reason = "Multiple Musicians On Same Part";
            end
            local name = "[" .. tostring(track.Id or i) .. "] " .. (track.Name or "");
            if reason then
                conflicts = conflicts + 1;
                AddLine(name .. " - " .. reason, "conflict");
            elseif good > 0 or synced > 0 then
                ready = ready + 1;
                -- Ordinary /play sync confirms the track but not necessarily
                -- the instrument. Never treat that as a conflict.
                local unverified = synced > (good + wrong) and
                    originalState ~= 1;
                AddLine(name .. (unverified and
                    " - Synced (Instrument Not Confirmed)" or
                    " - Synced"), "ready");
            else
                optional = optional + 1;
                AddLine(name .. " - Unfilled", "optional");
            end

            -- Merge the old Tracks Sync Info view into this one.
            local function DisplayInstrument(index)
                index = tonumber(index) or 0;
                local entry = self.Instruments_List and self.Instruments_List[index];
                return entry and entry[1] or "No Instrument";
            end
            local reportedPlayers = {};
            for n = 0, good - 1 do
                local player = state[2] and state[2][n];
                local index = state[3] and state[3][n];
                if player and player ~= "" then
                    reportedPlayers[string.lower(player)] = true;
                    AddLine("    " .. player .. " [" .. DisplayInstrument(index) .. "]", "ready");
                end
            end
            for n = 0, wrong - 1 do
                local player = state[5] and state[5][n];
                local index = state[6] and state[6][n];
                if player and player ~= "" then
                    reportedPlayers[string.lower(player)] = true;
                    AddLine("    " .. player .. " [" .. DisplayInstrument(index) .. "] - Wrong Instrument", "conflict");
                end
            end
            for n = 0, synced - 1 do
                local player = state[9] and state[9][n];
                if player and player ~= "" and not reportedPlayers[string.lower(player)] then
                    reportedPlayers[string.lower(player)] = true;
                    AddLine("    " .. player .. " [Instrument Not Confirmed]", "optional");
                end
            end
        end
    end
    local wrongSongs = {};
    for playerName, status in pairs(self.aPlayers or {}) do
        if type(status) == "string" and string.match(status, "^|[^|]+|1|") then
            local candidates = self.Players_Data and self.Players_Data[playerName];
            if type(candidates) == "table" and (tonumber(candidates[0]) or 0) > 0 then
                local found = false;
                for i = 1, tonumber(candidates[0]) do
                    if candidates[i] == Main.selectedSongIndex then found = true; break; end
                end
                if not found then wrongSongs[#wrongSongs+1] = playerName; end
            end
        end
    end
    if #wrongSongs > 0 then
        table.sort(wrongSongs);
        conflicts = conflicts + #wrongSongs;
        AddLine("Different Song: " .. table.concat(wrongSongs, ", "), "conflict");
    end
    self.readySummary:SetText(ready .. " Synced, " .. optional .. " Unfilled, " ..
        conflicts .. " Conflicts.\n" ..
        (conflicts > 0 and "Review conflicts or choose Start Song anyway." or
        "Unfilled parts do not prevent a synchronized start."));
    self.readyCheckConflictCount = conflicts;
    return conflicts;
end

-- Refresh the shortcut *before* the mouse is pressed: LOTRO only executes
-- commands from a real quickslot click, not from Lua event handlers.
function MainWindowClass:UpdateSyncStartPreflight()
    local count = self:RefreshReadyCheck() or 0;
    local alias = (count == 0 and Main.SongDB.Songs[Main.selectedSongIndex])
        and Strings["cmd_start"] or "";
    local kind = alias ~= "" and Turbine.UI.Lotro.ShortcutType.Alias
        or Turbine.UI.Lotro.ShortcutType.Undefined;
    self.syncStartSlotShortcut = Turbine.UI.Lotro.Shortcut(kind, alias);
    self.syncStartSlot:SetShortcut(self.syncStartSlotShortcut);
    return count;
end

function MainWindowClass:ShowReadyCheck(startRequested)
    self:RefreshReadyCheck();
    self.readyCheckWindow:SetText("Sync Check");
    self.readyCheckWindow:SetVisible(true);
    self.readyCheckWindow:Activate();
end
