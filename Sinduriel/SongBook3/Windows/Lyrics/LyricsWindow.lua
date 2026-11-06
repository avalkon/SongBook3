-- SongBook3 lyrics window.
local Main = Sinduriel.SongBook3.Windows.Main;
local MainWindowClass = Main.SongBook3Window;
local Helpers = Sinduriel.SongBook3.Windows.Main;
local ListControls = Sinduriel.SongBook3.Windows.Main;
local function SongBook3LyricPathForSong(song)
    if not song then return ""; end
    local directory = string.gsub(song.Filepath or "/", "\\", "/");
    if string.sub(directory, 1, 1) ~= "/" then directory = "/" .. directory; end
    if string.lower(string.sub(directory, 1, 7)) == "/songs/" then
        directory = string.sub(directory, 7);
        if directory == "" then directory = "/"; end
    end
    return string.lower(directory .. (song.Filename or ""));
end


function MainWindowClass:BuildLyricsLibrary()
    self.lyricEntries = { };
    self.lyricEntriesByDirectory = { };
    self.lyricDirectories = { "/" };
    self.lyricByKey = { };
    local directories = { ["/"] = true };

    local lyricRows = Main.SongBook3LyricsDB.Lyrics or { };
    for _, row in ipairs(lyricRows) do
        if type(row) == "table" and type(row.Filename) == "string" then
            local directory = string.gsub(row.Filepath or "/", "\\", "/");
            if string.sub(directory, 1, 1) ~= "/" then directory = "/" .. directory; end
            if string.sub(directory, -1) ~= "/" then directory = directory .. "/"; end
            local key = string.lower(directory .. row.Filename);
            local entry = {
                Source = "Text", Filepath = directory, Filename = row.Filename,
                Lines = row.Lines or { }, Key = key,
                DisplayName = row.Filename,
            };
            self.lyricEntries[#self.lyricEntries + 1] = entry;
            self.lyricByKey[key] = entry;
            local current = "/";
            for part in string.gmatch(directory, "([^/]+)") do
                current = current .. part .. "/";
                directories[current] = true;
            end
        end
    end

    self.lyricDirectories = { };
    for directory in pairs(directories) do
        self.lyricDirectories[#self.lyricDirectories + 1] = directory;
    end
    table.sort(self.lyricDirectories, function(a, b)
        if a == "/" then return b ~= "/"; end
        if b == "/" then return false; end
        return string.lower(a) < string.lower(b);
    end);

    for _, entry in ipairs(self.lyricEntries) do
        if not self.lyricEntriesByDirectory[entry.Filepath] then
            self.lyricEntriesByDirectory[entry.Filepath] = { };
        end
        table.insert(self.lyricEntriesByDirectory[entry.Filepath], entry);
    end
    for _, entries in pairs(self.lyricEntriesByDirectory) do
        table.sort(entries, function(a, b)
            return string.lower(a.Filename) < string.lower(b.Filename);
        end);
    end
end

function MainWindowClass:ResolveLyricsForSong(song)
    if not song then return nil; end
    local songKey = Helpers.SongBook3SongPath(song);
    local link = self.lyricLinks[songKey];
    if type(link) == "table" then
        local linked = self.lyricByKey[string.lower(link.Key or "")];
        if linked then return linked, "Saved SongBook3 link"; end
    end
    local textKey = SongBook3LyricPathForSong(song);
    local textEntry = self.lyricByKey[textKey];
    if textEntry then return textEntry, "Mirrored TXT path match"; end
    return nil, "No matching lyrics";
end

function MainWindowClass:PopulateLyricsDirectory()
    if not self.lyricDirList or self.refreshingLyricsUI then return; end
    self.refreshingLyricsUI = true;
    self.lyricDirList:ClearItems();
    if self.selectedLyricDir ~= "/" then
        local parent = string.gsub(self.selectedLyricDir, "[^/]+/$", "");
        if parent == "" then parent = "/"; end
        local up = Turbine.UI.Label();
        up:SetText("..");
        up:SetSize(1000, 20);
        up:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
        self.lyricDirList:AddItem(up);
    end
    for _, directory in ipairs(self.lyricDirectories) do
        local name = Helpers.SongBook3ImmediateChild(self.selectedLyricDir, directory);
        if name then
            local item = Turbine.UI.Label();
            item:SetText(name);
            item:SetSize(1000, 20);
            item:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
            self.lyricDirList:AddItem(item);
        end
    end

    self.lyricFileList:ClearItems();
    self.lyricLineList:ClearItems();
    self.selectedLyricEntry = nil;
    self.currentLyricLines = { };
    self.selectedLyricLine = 0;
    self:UpdateLyricsSendShortcut();
    for _, entry in ipairs(self.lyricEntriesByDirectory[self.selectedLyricDir] or { }) do
        local item = Turbine.UI.Label();
        item:SetText(entry.DisplayName or entry.Filename);
        item:SetSize(math.max(100, self.lyricFileList:GetWidth() - 8), 20);
        item:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
        item:SetForeColor(self.colourDefault);
        self.lyricFileList:AddItem(item);
    end
    self.lyricsStatus:SetText(self.selectedLyricDir .. "  |  " ..
        tostring(#(self.lyricEntriesByDirectory[self.selectedLyricDir] or { })) .. " lyric entries");
    self.refreshingLyricsUI = false;
end

function MainWindowClass:LoadLyricsEntry(entry)
    if not entry then return; end
    self.selectedLyricEntry = entry;
    local rawLines = entry.Lines or { };
    self.currentLyricLines = { };
    self.lyricLineList:ClearItems();
    local commentPrefix = tostring(Main.Settings.LyricsCommentPrefix or "");
    local ignoreBlankLines = Main.Settings.LyricsIgnoreBlankLines ~= "false";

    for sourceIndex, raw in ipairs(rawLines) do
        local displayText = tostring(raw or "");
        local isBlank = displayText == "";
        if not (isBlank and ignoreBlankLines) then
            local isSelectable = true;
            local isCommand = string.sub(displayText, 1, 1) == "/";
            if commentPrefix ~= "" and string.sub(displayText, 1, #commentPrefix) == commentPrefix then
                isSelectable = false;
            end
            local line = {
                Text = displayText, DisplayText = displayText,
                Selectable = isSelectable, Command = isCommand,
                SourceLine = sourceIndex,
            };
            self.currentLyricLines[#self.currentLyricLines + 1] = line;
            local item = Turbine.UI.Label();
            item:SetMultiline(false);
            item:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
            item:SetText(string.format("%03d  %s", sourceIndex, displayText));
            item:SetSize(math.max(self.lyricLineList:GetWidth() - 8, #displayText * 8 + 60), 20);
            if isSelectable then
                item:SetForeColor(self.colourDefault);
            else
                item:SetForeColor(Turbine.UI.Color(0.65, 0.55, 0.55, 0.55));
            end
            line.Item = item;
            self.lyricLineList:AddItem(item);
        end
    end

    self.selectedLyricLine = 0;
    for i, line in ipairs(self.currentLyricLines) do
        if line.Selectable then self.selectedLyricLine = i; break; end
    end
    if self.selectedLyricLine > 0 then
        self.lyricLineList:SetSelectedIndex(self.selectedLyricLine);
    else
        self.lyricLineList:SetSelectedIndex(0);
    end
    self.lyricsStatus:SetText((entry.Filepath or "/") .. (entry.Filename or "") ..
        "  |  TXT  |  " .. tostring(#self.currentLyricLines) .. " lines");
    self:UpdateLyricsFileHighlight();
    self:UpdateLyricsLineHighlight();
    self:UpdateLyricsSendShortcut();
end

function MainWindowClass:UpdateLyricsFileHighlight()
    if not self.lyricFileList then return; end
    local entries = self.lyricEntriesByDirectory[self.selectedLyricDir] or { };
    for i, entry in ipairs(entries) do
        local item = self.lyricFileList:GetItem(i);
        if item then
            item:SetForeColor(entry == self.selectedLyricEntry and
                self.colourDefaultHighlighted or self.colourDefault);
        end
    end
end

function MainWindowClass:UpdateLyricsLineHighlight()
    if not self.lyricLineList then return; end
    for i, line in ipairs(self.currentLyricLines or { }) do
        local item = line.Item or self.lyricLineList:GetItem(i);
        if item then
            if i == self.selectedLyricLine then
                item:SetForeColor(self.colourDefaultHighlighted);
            elseif line.Colour then
                item:SetForeColor(line.Colour);
            elseif line.Selectable then
                item:SetForeColor(self.colourDefault);
            else
                item:SetForeColor(Turbine.UI.Color(0.65, 0.55, 0.55, 0.55));
            end
        end
    end
end

function MainWindowClass:SelectLyricsEntry(entry)
    if not entry or not self.lyricFileList then return false; end
    self.selectedLyricDir = entry.Filepath or "/";
    self:PopulateLyricsDirectory();
    local entries = self.lyricEntriesByDirectory[self.selectedLyricDir] or { };
    local found = nil;
    for i, candidate in ipairs(entries) do
        if candidate == entry or candidate.Key == entry.Key then found = i; break; end
    end
    if found then
        self.refreshingLyricsUI = true;
        self.lyricFileList:SetSelectedIndex(found);
        self.refreshingLyricsUI = false;
    end
    self:LoadLyricsEntry(entry);
    return found ~= nil;
end

function MainWindowClass:JumpToMainSongLyrics()
    local song = Main.SongDB.Songs[Main.selectedSongIndex];
    if not song then
        self.lyricsStatus:SetText("Select a song in the main SongBook3 window first.");
        return;
    end
    local entry, reason = self:ResolveLyricsForSong(song);
    if not entry then
        self.selectedLyricEntry = nil;
        self.currentLyricLines = { };
        self.selectedLyricLine = 0;
        self.refreshingLyricsUI = true;
        self.lyricFileList:SetSelectedIndex(0);
        self.refreshingLyricsUI = false;
        self.lyricLineList:ClearItems();
        self:UpdateLyricsSendShortcut();
        self.lyricsStatus:SetText("No lyrics found for " .. (song.Filename or "this song") ..
            ". Browse the mirrored TXT folders, then Link To Main Song.");
        return;
    end
    self:SelectLyricsEntry(entry);
    self.lyricsStatus:SetText((song.Filepath or "/") .. (song.Filename or "") ..
        "  ->  TXT  (" .. reason .. ")");
end

function MainWindowClass:SaveLyricLinks()
    Main.SongBook3Save(Turbine.DataScope.Account, "SongBook3LyricLinks", self.lyricLinks,
        function(ok, message)
            if not ok then
                Turbine.Shell.WriteLine("SongBook3 lyric-link save failed: " .. tostring(message));
                if self.lyricsStatus then self.lyricsStatus:SetText("Could not save lyric link: " .. tostring(message)); end
            end
        end);
end

function MainWindowClass:LinkCurrentLyricsToMainSong()
    local song = Main.SongDB.Songs[Main.selectedSongIndex];
    local entry = self.selectedLyricEntry;
    if not song then self.lyricsStatus:SetText("Select a main-window song first."); return; end
    if not entry then self.lyricsStatus:SetText("Select a TXT lyric file first."); return; end
    self.lyricLinks[Helpers.SongBook3SongPath(song)] = { Key = entry.Key };
    self:SaveLyricLinks();
    self.lyricsStatus:SetText("Linked " .. (song.Filename or "song") .. " to " .. (entry.DisplayName or entry.Filename) .. ".");
end

function MainWindowClass:ClearCurrentLyricsLink()
    local song = Main.SongDB.Songs[Main.selectedSongIndex];
    if not song then self.lyricsStatus:SetText("Select a main-window song first."); return; end
    local key = Helpers.SongBook3SongPath(song);
    if not self.lyricLinks[key] then
        self.lyricsStatus:SetText("This song has no manual lyric link.");
        return;
    end
    self.lyricLinks[key] = nil;
    self:SaveLyricLinks();
    self.lyricsStatus:SetText("Manual lyric link cleared. Using mirrored-path matching again.");
    self:JumpToMainSongLyrics();
end

function MainWindowClass:GetLyricsDelay()
    local delay = tonumber(Main.Settings.LyricsDelay) or 0;
    delay = math.floor(delay);
    if delay < 0 then delay = 0; end
    if delay > 5 then delay = 5; end
    return delay;
end

function MainWindowClass:UpdateLyricsSendShortcut()
    if not self.lyricsSendSlot then return; end
    local line = self.currentLyricLines and self.currentLyricLines[self.selectedLyricLine] or nil;
    if self.lyricsSendCoolingDown then
        self.lyricsSendSlot:SetVisible(false);
        self.lyricsSendIcon:SetVisible(line ~= nil and line.Selectable == true);
        self.lyricsSendIcon:SetBackground(gDir .. "icn_song_down.tga");
        self.lyricsSendText:SetText(line and line.Selectable and "Waiting for next line..." or "");
        return;
    end
    if not line or not line.Selectable then
        self.lyricsSendSlot:SetShortcut(Turbine.UI.Lotro.Shortcut(
            Turbine.UI.Lotro.ShortcutType.Undefined, ""));
        self.lyricsSendSlot:SetVisible(false);
        self.lyricsSendIcon:SetVisible(false);
        self.lyricsSendIcon:SetBackground(gDir .. "icn_song.tga");
        self.lyricsSendText:SetText("Select a lyric line");
        return;
    end
    local prefix = tostring(Main.Settings.LyricsPrefix or "");
    prefix = string.gsub(prefix, "%s+$", "");
    local alias;
    if line.Command then
        alias = line.Text;
    else
        local message = (prefix ~= "" and (prefix .. " ") or "") .. line.Text;
        alias = "/say " .. message;
    end
    self.lyricsSendShortcut = Turbine.UI.Lotro.Shortcut(
        Turbine.UI.Lotro.ShortcutType.Alias, alias);
    self.lyricsSendSlot:SetShortcut(self.lyricsSendShortcut);
    self.lyricsSendSlot:SetVisible(true);
    self.lyricsSendIcon:SetVisible(true);
    self.lyricsSendIcon:SetBackground(gDir .. "icn_song.tga");
    self.lyricsSendText:SetText("Send Line " .. tostring(self.selectedLyricLine) ..
        " / " .. tostring(#(self.currentLyricLines or { })));
end

function MainWindowClass:MoveLyricsLine(delta)
    local count = #(self.currentLyricLines or { });
    if count < 1 then return; end
    local index = self.selectedLyricLine or 0;
    if index < 1 then index = delta > 0 and 0 or count + 1; end
    repeat
        index = index + delta;
        if index < 1 or index > count then return; end
    until self.currentLyricLines[index] and self.currentLyricLines[index].Selectable;
    self.selectedLyricLine = index;
    self.lyricLineList:SetSelectedIndex(index);
    self:UpdateLyricsLineHighlight();
    self:UpdateLyricsSendShortcut();
end

function MainWindowClass:AdvanceLyricsAfterSend()
    local count = #(self.currentLyricLines or { });
    local index = self.selectedLyricLine or 0;
    for i = index + 1, count do
        if self.currentLyricLines[i] and self.currentLyricLines[i].Selectable then
            self.selectedLyricLine = i;
            self.lyricLineList:SetSelectedIndex(i);
            self:UpdateLyricsLineHighlight();
            self:UpdateLyricsSendShortcut();
            return true;
        end
    end
    self.selectedLyricLine = 0;
    self.lyricLineList:SetSelectedIndex(0);
    self:UpdateLyricsLineHighlight();
    self:UpdateLyricsSendShortcut();
    return false;
end

function MainWindowClass:LayoutLyricsWindow()
    if not self.lyricsWindow or not self.lyricDirList then return; end
    local width, height = self.lyricsWindow:GetSize();
    self.lyricsJumpButton:SetPosition(18, 43);
    self.lyricsJumpButton:SetSize(150, 25);
    self.lyricsLinkButton:SetPosition(176, 43);
    self.lyricsLinkButton:SetSize(142, 25);
    self.lyricsClearLinkButton:SetPosition(326, 43);
    self.lyricsClearLinkButton:SetSize(112, 25);
    self.lyricsStatus:SetPosition(18, 74);
    self.lyricsStatus:SetSize(width - 36, 20);
    local frameTop = 101;
    local footerTop = height - 57;
    local frameHeight = footerTop - frameTop - 28;
    local bodyTop = frameTop + 13;
    -- Keep the 13px top inset and a 7px bottom inset, matching the other windows.
    local bodyHeight = frameHeight - 20;
    self.lyricsFrame:SetPosition(12, frameTop);
    self.lyricsFrame:SetSize(width - 23, frameHeight);
    self.lyricsBody:SetPosition(18, bodyTop);
    self.lyricsBody:SetSize(width - 28, bodyHeight);
    local bodyWidth = width - 28;
    local listWidth = bodyWidth - 10;
    local dirHeight = math.max(45, math.min(self.lyricsDirHeight, bodyHeight - 210));
    local fileHeight = math.max(55, math.min(self.lyricsFileHeight, bodyHeight - dirHeight - 120));
    self.lyricDirList:SetPosition(0, 0);
    self.lyricDirList:SetSize(listWidth, dirHeight);
    self.lyricsDivider1:SetPosition(0, dirHeight);
    self.lyricsDivider1:SetSize(bodyWidth, 13);
    self.lyricFileList:SetPosition(0, dirHeight + 13);
    self.lyricFileList:SetSize(listWidth, fileHeight);
    local lineTop = dirHeight + 13 + fileHeight + 13;
    self.lyricsDivider2:SetPosition(0, lineTop - 13);
    self.lyricsDivider2:SetSize(bodyWidth, 13);
    self.lyricLineList:SetPosition(0, lineTop);
    self.lyricLineList:SetSize(listWidth, math.max(30, bodyHeight - lineTop));
    self.lyricLineHScroll:SetPosition(0, bodyHeight - 13);
    self.lyricLineHScroll:SetSize(listWidth, 13);
    self.lyricsFolderHeading:SetSize(130, 13);
    self.lyricsFileHeading:SetSize(130, 13);
    self.lyricsLineHeading:SetSize(130, 13);
    self.lyricsDividerArrows1:SetPosition(math.floor(bodyWidth / 2) - 10, 1);
    self.lyricsDividerArrows2:SetPosition(math.floor(bodyWidth / 2) - 10, 1);
    for i = 1, self.lyricFileList:GetItemCount() do
        local item = self.lyricFileList:GetItem(i);
        if item then item:SetSize(math.max(100, listWidth - 8), 20); end
    end
    for i = 1, self.lyricLineList:GetItemCount() do
        local item = self.lyricLineList:GetItem(i);
        if item then item:SetSize(math.max(listWidth - 8, #(item:GetText() or "") * 8 + 30), 20); end
    end
    self.lyricsPrevButton:SetPosition(18, footerTop);
    self.lyricsPrevButton:SetSize(82, 25);
    self.lyricsRestartButton:SetPosition(106, footerTop);
    self.lyricsRestartButton:SetSize(82, 25);
    local slotX = math.floor(width / 2) - 17;
    self.lyricsSendSlot:SetPosition(slotX, footerTop - 4);
    self.lyricsSendIcon:SetPosition(slotX, footerTop - 4);
    self.lyricsSendText:SetPosition(slotX + 42, footerTop - 1);
    self.lyricsSendText:SetSize(118, 25);
    self.lyricsNextButton:SetPosition(width - 100, footerTop);
    self.lyricsNextButton:SetSize(82, 25);
end

function MainWindowClass:CreateLyricsWindow()
    self.lyricsWindow = Turbine.UI.Lotro.Window();
    self.lyricsWindow:SetText("Lyrics");
    self.lyricsWindow:SetSize(Helpers.SongBook3SavedWindowSize("Lyrics", 620, 620, 500, 480));
    self.lyricsWindow:SetZOrder(185);
    self.lyricsWindow:SetVisible(false);
    local position = Main.Settings.LyricsWindowPosition or { };
    local displayWidth, displayHeight = Turbine.UI.Display.GetSize();
    local left = tonumber(position.Left) or 420;
    local top = tonumber(position.Top) or 120;
    left = math.max(0, math.min(left, math.max(0, displayWidth - self.lyricsWindow:GetWidth())));
    top = math.max(0, math.min(top, math.max(0, displayHeight - self.lyricsWindow:GetHeight())));
    self.lyricsWindow:SetPosition(left, top);

    self.lyricsJumpButton = Turbine.UI.Lotro.Button();
    self.lyricsJumpButton:SetParent(self.lyricsWindow);
    self.lyricsJumpButton:SetText("Jump to Main Song");
    self.lyricsJumpButton.MouseClick = function() self:JumpToMainSongLyrics(); end;
    self.lyricsLinkButton = Turbine.UI.Lotro.Button();
    self.lyricsLinkButton:SetParent(self.lyricsWindow);
    self.lyricsLinkButton:SetText("Link To Main Song");
    self.lyricsLinkButton.MouseClick = function() self:LinkCurrentLyricsToMainSong(); end;
    self.lyricsClearLinkButton = Turbine.UI.Lotro.Button();
    self.lyricsClearLinkButton:SetParent(self.lyricsWindow);
    self.lyricsClearLinkButton:SetText("Clear Link");
    self.lyricsClearLinkButton.MouseClick = function() self:ClearCurrentLyricsLink(); end;
    self.lyricsStatus = Turbine.UI.Label();
    self.lyricsStatus:SetParent(self.lyricsWindow);
    self.lyricsStatus:SetText("Browse mirrored TXT lyrics. Selection is independent of the main song.");
    self.lyricsStatus:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);

    self.lyricsFrame = Turbine.UI.Control();
    self.lyricsFrame:SetParent(self.lyricsWindow);
    self.lyricsFrame:SetBackColor(Turbine.UI.Color(1, 0.15, 0.15, 0.15));
    self.lyricsBody = Turbine.UI.Control();
    self.lyricsBody:SetParent(self.lyricsWindow);
    self.lyricsBody:SetBackColor(Turbine.UI.Color(1, 0, 0, 0));
    self.lyricsFolderHeading = Turbine.UI.Label();
    self.lyricsFolderHeading:SetParent(self.lyricsFrame);
    self.lyricsFolderHeading:SetPosition(5, 0);
    self.lyricsFolderHeading:SetFont(Turbine.UI.Lotro.Font.TrajanPro13);
    self.lyricsFolderHeading:SetText("Folders");
    self.lyricsFolderHeading:SetMouseVisible(false);

    self.lyricDirList = ListControls.ListBoxScrolled:New(10);
    self.lyricDirList:SetParent(self.lyricsBody);
    self.lyricDirList:SetVisible(true);
    self.lyricDirList.SelectedIndexChanged = function(sender)
        if self.refreshingLyricsUI then return; end
        local item = sender:GetSelectedItem();
        if not item then return; end
        local name = item:GetText();
        if name == ".." then
            local parent = string.gsub(self.selectedLyricDir, "[^/]+/$", "");
            if parent == "" then parent = "/"; end
            self.selectedLyricDir = parent;
        else
            self.selectedLyricDir = self.selectedLyricDir .. name;
        end
        self:PopulateLyricsDirectory();
    end;

    self.lyricsDividerArrows1 = Turbine.UI.Control();
    self.lyricsDividerArrows1:SetParent(self.lyricsBody);
    self.lyricsDividerArrows1:SetBackground(gDir .. "arrows.tga");
    self.lyricsDividerArrows1:SetSize(20, 10);
    self.lyricsDividerArrows1:SetMouseVisible(false);
    self.lyricsDivider1 = Turbine.UI.Control();
    self.lyricsDivider1:SetParent(self.lyricsBody);
    self.lyricsDivider1:SetBackColor(Turbine.UI.Color(1, 0.15, 0.15, 0.15));
    self.lyricsDivider1:SetZOrder(300);
    -- Keep the arrows above the draggable divider, as in the main and setlist windows.
    self.lyricsDividerArrows1:SetParent(self.lyricsDivider1);
    self.lyricsDivider1:SetMouseVisible(true);
    self.lyricsDivider1.MouseDown = function(sender, args)
        if args.Button ~= Turbine.UI.MouseButton.Left then return; end
        sender.dragging = true;
        sender.dragStartY = args.Y;
        -- Capture the actual displayed pane heights, then keep the lower
        -- divider fixed while redistributing space between Folders and Files.
        local bodyHeight = self.lyricsBody:GetHeight();
        local dirHeight = math.max(45, math.min(self.lyricsDirHeight, bodyHeight - 210));
        local fileHeight = math.max(55, math.min(self.lyricsFileHeight, bodyHeight - dirHeight - 120));
        self.lyricsDirHeight = dirHeight;
        self.lyricsFileHeight = fileHeight;
        sender.startBottom = dirHeight + fileHeight;
    end;
    self.lyricsDivider1.MouseMove = function(sender, args)
        if not sender.dragging then return; end
        local bodyHeight = self.lyricsBody:GetHeight();
        local maxDirHeight = math.min(bodyHeight - 210, sender.startBottom - 55);
        self.lyricsDirHeight = math.max(45, math.min(maxDirHeight,
            self.lyricsDirHeight + args.Y - sender.dragStartY));
        self.lyricsFileHeight = sender.startBottom - self.lyricsDirHeight;
        self:LayoutLyricsWindow();
    end;
    self.lyricsDivider1.MouseUp = function(sender)
        sender.dragging = false;
        self:SaveSettings();
    end;

    self.lyricsFileHeading = Turbine.UI.Label();
    self.lyricsFileHeading:SetParent(self.lyricsDivider1);
    self.lyricsFileHeading:SetFont(Turbine.UI.Lotro.Font.TrajanPro13);
    self.lyricsFileHeading:SetText("Files");
    self.lyricsFileHeading:SetMouseVisible(false);
    self.lyricsDividerArrows2 = Turbine.UI.Control();
    self.lyricsDividerArrows2:SetParent(self.lyricsBody);
    self.lyricsDividerArrows2:SetBackground(gDir .. "arrows.tga");
    self.lyricsDividerArrows2:SetSize(20, 10);
    self.lyricsDividerArrows2:SetMouseVisible(false);
    self.lyricsDivider2 = Turbine.UI.Control();
    self.lyricsDivider2:SetParent(self.lyricsBody);
    self.lyricsDivider2:SetBackColor(Turbine.UI.Color(1, 0.15, 0.15, 0.15));
    self.lyricsDivider2:SetZOrder(300);
    self.lyricsDividerArrows2:SetParent(self.lyricsDivider2);
    self.lyricsDivider2:SetMouseVisible(true);
    self.lyricsDivider2.MouseDown = function(sender, args)
        if args.Button ~= Turbine.UI.MouseButton.Left then return; end
        sender.dragging = true;
        sender.dragStartY = args.Y;
    end;
    self.lyricsDivider2.MouseMove = function(sender, args)
        if not sender.dragging then return; end
        local bodyHeight = self.lyricsBody:GetHeight();
        self.lyricsFileHeight = math.max(55, math.min(
            bodyHeight - self.lyricsDirHeight - 120,
            self.lyricsFileHeight + args.Y - sender.dragStartY));
        self:LayoutLyricsWindow();
    end;
    self.lyricsDivider2.MouseUp = function(sender)
        sender.dragging = false;
        self:SaveSettings();
    end;
    self.lyricsLineHeading = Turbine.UI.Label();
    self.lyricsLineHeading:SetParent(self.lyricsDivider2);
    self.lyricsLineHeading:SetFont(Turbine.UI.Lotro.Font.TrajanPro13);
    self.lyricsLineHeading:SetText("Lyrics");
    self.lyricsLineHeading:SetMouseVisible(false);

    self.lyricFileList = ListControls.ListBoxScrolled:New(10);
    self.lyricFileList:SetParent(self.lyricsBody);
    self.lyricFileList:SetVisible(true);
    self.lyricFileList.SelectedIndexChanged = function(sender)
        if self.refreshingLyricsUI then return; end
        local index = sender:GetSelectedIndex();
        local entry = (self.lyricEntriesByDirectory[self.selectedLyricDir] or { })[index];
        if entry then self:LoadLyricsEntry(entry); end
        self:UpdateLyricsFileHighlight();
    end;
    self.lyricLineList = ListControls.ListBoxScrolled:New(10);
    self.lyricLineList:SetParent(self.lyricsBody);
    self.lyricLineList:SetVisible(true);
    self.lyricLineHScroll = Turbine.UI.Lotro.ScrollBar();
    self.lyricLineHScroll:SetParent(self.lyricsBody);
    self.lyricLineHScroll:SetOrientation(Turbine.UI.Orientation.Horizontal);
    self.lyricLineHScroll:SetBackColor(Turbine.UI.Color(1, .1, .1, .1));
    self.lyricLineList:SetHorizontalScrollBar(self.lyricLineHScroll);
    self.lyricLineList.SelectedIndexChanged = function(sender)
        if self.refreshingLyricsUI then return; end
        local index = sender:GetSelectedIndex();
        if index and index > 0 then
            self.selectedLyricLine = index;
            self:UpdateLyricsLineHighlight();
            self:UpdateLyricsSendShortcut();
        end
    end;

    self.lyricsPrevButton = Turbine.UI.Lotro.Button();
    self.lyricsPrevButton:SetParent(self.lyricsWindow);
    self.lyricsPrevButton:SetText("Previous");
    self.lyricsPrevButton.MouseClick = function() self:MoveLyricsLine(-1); end;
    self.lyricsRestartButton = Turbine.UI.Lotro.Button();
    self.lyricsRestartButton:SetParent(self.lyricsWindow);
    self.lyricsRestartButton:SetText("Restart");
    self.lyricsRestartButton.MouseClick = function()
        for i, line in ipairs(self.currentLyricLines or { }) do
            if line.Selectable then
                self.selectedLyricLine = i;
                self.lyricLineList:SetSelectedIndex(i);
                self:UpdateLyricsLineHighlight();
                self:UpdateLyricsSendShortcut();
                return;
            end
        end
    end;
    self.lyricsSendSlot = Turbine.UI.Lotro.Quickslot();
    self.lyricsSendSlot:SetParent(self.lyricsWindow);
    self.lyricsSendSlot:SetSize(32, 30);
    self.lyricsSendSlot:SetZOrder(100);
    self.lyricsSendSlot:SetAllowDrop(false);
    self.lyricsSendSlot:SetVisible(false);
    self.lyricsSendSlot.DragDrop = function() self:UpdateLyricsSendShortcut(); end;
    self.lyricsSendUpdateControl = Turbine.UI.Control();
    self.lyricsSendUpdateState = 0;
    self.lyricsSendUpdateCount = 0;
    self.lyricsSendCoolingDown = false;
    self.lyricsSendDelayUntil = 0;
    self.lyricsSendSlot.MouseClick = function(sender, args)
        if self.lyricsSendCoolingDown then return; end
        self.lyricsSendUpdateState = 1;
        self.lyricsSendUpdateCount = 0;
        self.lyricsSendUpdateControl:SetWantsUpdates(true);
    end;
    self.lyricsSendUpdateControl.Update = function(sender, args)
        local now = Turbine.Engine.GetGameTime();
        if self.lyricsSendUpdateState == 1 then
            local delay = self:GetLyricsDelay();
            self.lyricsSendCoolingDown = delay > 0;
            self:AdvanceLyricsAfterSend();
            if delay > 0 then
                self.lyricsSendDelayUntil = now + delay;
                self.lyricsSendUpdateState = 2;
                self.lyricsSendUpdateCount = 0;
                self:UpdateLyricsSendShortcut();
            else
                self.lyricsSendUpdateState = 0;
                sender:SetWantsUpdates(false);
            end
        elseif self.lyricsSendUpdateState == 2 then
            self.lyricsSendUpdateCount = self.lyricsSendUpdateCount + 1;
            if now >= self.lyricsSendDelayUntil and self.lyricsSendUpdateCount > 50 then
                self.lyricsSendCoolingDown = false;
                self.lyricsSendUpdateState = 0;
                self.lyricsSendUpdateCount = 0;
                sender:SetWantsUpdates(false);
                self:UpdateLyricsSendShortcut();
            end
        end
    end;
    self.lyricsSendIcon = Turbine.UI.Control();
    self.lyricsSendIcon:SetParent(self.lyricsWindow);
    self.lyricsSendIcon:SetSize(35, 35);
    self.lyricsSendIcon:SetZOrder(110);
    self.lyricsSendIcon:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend);
    self.lyricsSendIcon:SetBackground(gDir .. "icn_song.tga");
    self.lyricsSendIcon:SetMouseVisible(false);
    self.lyricsSendText = Turbine.UI.Label();
    self.lyricsSendText:SetParent(self.lyricsWindow);
    self.lyricsSendText:SetText("Select a lyric line");
    self.lyricsSendText:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
    self.lyricsSendText:SetMouseVisible(false);
    self.lyricsSendSlot.MouseEnter = function() self.lyricsSendIcon:SetBackground(gDir .. "icn_song_hover.tga"); end;
    self.lyricsSendSlot.MouseLeave = function() self.lyricsSendIcon:SetBackground(gDir .. "icn_song.tga"); end;
    self.lyricsSendSlot.MouseDown = function() self.lyricsSendIcon:SetBackground(gDir .. "icn_song_down.tga"); end;
    self.lyricsSendSlot.MouseUp = function() self.lyricsSendIcon:SetBackground(gDir .. "icn_song_hover.tga"); end;
    self.lyricsNextButton = Turbine.UI.Lotro.Button();
    self.lyricsNextButton:SetParent(self.lyricsWindow);
    self.lyricsNextButton:SetText("Next");
    self.lyricsNextButton.MouseClick = function() self:MoveLyricsLine(1); end;

    self.lyricsDirHeight = tonumber(Main.Settings.LyricsDirHeight) or 90;
    self.lyricsFileHeight = tonumber(Main.Settings.LyricsFileHeight) or 125;
    self.lyricsWindow.Closed = function()
        self:SaveSettings();
        self.lyricsWindow:SetVisible(false);
    end;
    self.lyricsResize = Helpers.SongBook3AttachResizeGrip(self.lyricsWindow, 500, 480,
        function() self:LayoutLyricsWindow(); end,
        function() self:SaveSettings(); end);
    self.lyricDirList:SetVisible(true);
    self.lyricFileList:SetVisible(true);
    self.lyricLineList:SetVisible(true);
    self.lyricLineHScroll:SetVisible(true);
    self:LayoutLyricsWindow();
    self:PopulateLyricsDirectory();
end

