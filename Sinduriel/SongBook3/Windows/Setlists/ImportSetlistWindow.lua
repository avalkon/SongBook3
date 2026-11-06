-- Import Setlist confirmation window.
local MainWindowClass = Sinduriel.SongBook3.Windows.Main.SongBook3Window;
function MainWindowClass:CreateImportSetlistWindow()
    self.receivedSetlistWindow = Turbine.UI.Lotro.Window();
    self.receivedSetlistWindow:SetText("Import Setlist");
    self.receivedSetlistWindow:SetSize(465, 195);
    self.receivedSetlistWindow:SetPosition(310, 180);
    self.receivedSetlistWindow:SetZOrder(205);
    self.receivedSetlistWindow:SetVisible(false);
    self.receivedSetlistLabel = Turbine.UI.Label();
    self.receivedSetlistLabel:SetParent(self.receivedSetlistWindow);
    self.receivedSetlistLabel:SetPosition(20, 46);
    self.receivedSetlistLabel:SetSize(425, 66);
    self.receivedSetlistLabel:SetMultiline(true);
    local importBtn = Turbine.UI.Lotro.Button();
    importBtn:SetParent(self.receivedSetlistWindow);
    importBtn:SetPosition(32, 128);
    importBtn:SetSize(176, 27);
    importBtn:SetText("Import Setlist");
    importBtn.MouseClick = function() self:ImportReceivedSetlist(); end;
    local discardBtn = Turbine.UI.Lotro.Button();
    discardBtn:SetParent(self.receivedSetlistWindow);
    discardBtn:SetPosition(242, 128);
    discardBtn:SetSize(176, 27);
    discardBtn:SetText("Discard");
    discardBtn.MouseClick = function()
        self.pendingReceivedSetlist = nil;
        self.receivedSetlistWindow:SetVisible(false);
    end;
    self.incomingSetlists = {};


end

function MainWindowClass:ImportReceivedSetlist()
    local received = self.pendingReceivedSetlist;
    if not received then return; end
    local base = string.sub(received.name .. " (Shared)", 1, 55);
    local name = base;
    local i = 2;
    while self.setlistData.lists[name] do
        local suffix = " (" .. i .. ")";
        name = string.sub(base, 1, 55 - #suffix) .. suffix;
        i = i + 1;
    end
    self.setlistData.lists[name] = received.songs;
    table.insert(self.setlistData.names, name);
    self.activeSetlist = name;
    self.activeSetlistPosition = 0;
    self.currentSetlistPlayingIndex = 0;
    self:SaveSetlistData();
    self:RefreshSetlistUI();
    self.setlistNote:SetText("Imported From " .. received.sender ..
        ". Changes Save Automatically. Missing songs need the same library paths.");
    self.pendingReceivedSetlist = nil;
    self.receivedSetlistWindow:SetVisible(false);
    self.setlistWindow:SetVisible(true);
    self.setlistWindow:Activate();
end


