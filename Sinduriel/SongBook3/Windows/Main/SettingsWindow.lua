local Main = Sinduriel.SongBook3.Windows.Main;

SettingsWindow = class( Turbine.UI.Lotro.Window );


function SettingsWindow:NextPos( delta )
	delta = delta or 20
	self.yPos = self.yPos + delta
	return self.yPos
end

function SettingsWindow:CreateCheckBox( stringCode, yPos, state, func, width, xPos )
	width = width or 260
	xPos = xPos or 25
	local cb = Turbine.UI.Lotro.CheckBox();
	cb:SetParent( self.generalPanel );
	cb:SetPosition(xPos, yPos );
	cb:SetSize(width,20);
	cb:SetText(" " .. Strings[stringCode]);
	cb:SetChecked(state == "yes" or state == "true" );
	cb.CheckedChanged = func
	return cb
end
	
function SettingsWindow:Constructor()
	Turbine.UI.Lotro.Window.Constructor( self );
	
	local sCmd = 0;
	
    -- Resize the settings window without requiring a large game viewport.
    -- Only the content scrolls: tabs, Save, Help and native title stay fixed.
    local displayWidth, displayHeight = Turbine.UI.Display.GetSize();
    local wndWidth, wndHeight = Main.SongBook3SavedWindowSize("Settings", 570, 580, 345, 275);
    local mainLeft = tonumber(Main.Settings.WindowPosition.Left) or 300;
    local mainTop = tonumber(Main.Settings.WindowPosition.Top) or 0;
    local xPos = mainLeft < 300 and 0 or mainLeft - 300;
    local yPos = mainTop + 100;
    self:SetPosition(math.max(0, math.min(xPos, displayWidth - wndWidth)),
                     math.max(0, math.min(yPos, displayHeight - wndHeight)));
    self:SetSize(wndWidth, wndHeight);
    self:SetText(Strings["ui_settings"]);

    -- The viewport clips off-screen controls; the content panel is moved
    -- vertically by a normal LOTRO scrollbar. Keeping the viewport below
    -- the tabs also avoids intercepting window dragging and closing.
    self.generalViewport = Turbine.UI.Control();
    self.generalViewport:SetParent(self);
    self.generalViewport:SetPosition(8, 70);
    self.generalViewport:SetMouseVisible(true);
    self.generalPanel = Turbine.UI.Control();
    self.generalPanel:SetParent(self.generalViewport);
    self.generalPanel:SetPosition(0, -65);
    self.generalPanel:SetSize(540, 650);
    self.generalPanel:SetMouseVisible(false);
    self.generalScrollbar = Turbine.UI.Lotro.ScrollBar();
    self.generalScrollbar:SetParent(self);
    self.generalScrollbar:SetOrientation(Turbine.UI.Orientation.Vertical);
    self.generalScrollbar:SetSmallChange(22);
    self.generalScrollbar:SetMinimum(0);
    self.generalScrollbar:SetValue(0);
    self.generalScrollbar.ValueChanged = function(sender, args)
        self.generalPanel:SetTop(-65 - sender:GetValue());
    end;

    self.lyricsViewport = Turbine.UI.Control();
    self.lyricsViewport:SetParent(self);
    self.lyricsViewport:SetPosition(8, 70);
    self.lyricsViewport:SetMouseVisible(true);
    self.lyricsPanel = Turbine.UI.Control();
    self.lyricsPanel:SetParent(self.lyricsViewport);
    self.lyricsPanel:SetPosition(0, 0);
    self.lyricsPanel:SetSize(540, 380);
    self.lyricsPanel:SetBackColor(Turbine.UI.Color(1, 0.08, 0.08, 0.08));
    self.lyricsPanel:SetMouseVisible(false);
    self.lyricsScrollbar = Turbine.UI.Lotro.ScrollBar();
    self.lyricsScrollbar:SetParent(self);
    self.lyricsScrollbar:SetOrientation(Turbine.UI.Orientation.Vertical);
    self.lyricsScrollbar:SetSmallChange(22);
    self.lyricsScrollbar:SetMinimum(0);
    self.lyricsScrollbar:SetValue(0);
    self.lyricsScrollbar.ValueChanged = function(sender, args)
        self.lyricsPanel:SetTop(-sender:GetValue());
    end;
    self.generalViewport.MouseWheel = function(sender, args)
        self:ScrollSettingsPane(false, args.Direction);
    end;
    self.generalPanel.MouseWheel = self.generalViewport.MouseWheel;
    self.lyricsViewport.MouseWheel = function(sender, args)
        self:ScrollSettingsPane(true, args.Direction);
    end;
    self.lyricsPanel.MouseWheel = self.lyricsViewport.MouseWheel;
    self.generalTabButton = Turbine.UI.Lotro.Button();
    self.generalTabButton:SetParent(self);
    self.generalTabButton:SetPosition(20, 40);
    self.generalTabButton:SetSize(100, 24);
    self.generalTabButton:SetText("General");
    self.generalTabButton:SetZOrder(20);
    self.generalTabButton.MouseClick = function() self:ShowTab("General"); end;

    self.lyricsTabButton = Turbine.UI.Lotro.Button();
    self.lyricsTabButton:SetParent(self);
    self.lyricsTabButton:SetPosition(128, 40);
    self.lyricsTabButton:SetSize(100, 24);
    self.lyricsTabButton:SetText("Lyrics");
    self.lyricsTabButton:SetZOrder(20);
    self.lyricsTabButton.MouseClick = function() self:ShowTab("Lyrics"); end;

	self.yPos = 50
	-- general settings label
	self.genLabel = Turbine.UI.Label();
	self.genLabel:SetParent(self.generalPanel);
	self.genLabel:SetPosition(20,self:NextPos(20));
	self.genLabel:SetWidth(260);
	self.genLabel:SetForeColor(Turbine.UI.Color(1,0.77,0.64,0.22));
	self.genLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 );
	self.genLabel:SetText(Strings["ui_general"]);

	--Track display checkbox
	self.trackCheck = self:CreateCheckBox( "cb_parts", self:NextPos(20), Main.Settings.TracksVisible,
		function(sender, args) songBook3Window:ToggleTracks(); end )
	
	--Search function enabled checkbox
	self.searchCheck = self:CreateCheckBox( "cb_search", self:NextPos(), Main.Settings.SearchVisible,
		function(sender, args) songBook3Window:ToggleSearch(); end )
	
	--Show description in song list checkbox
	self.descCheck = self:CreateCheckBox( "cb_desc", self:NextPos(), Main.Settings.DescriptionVisible,
		function(sender, args) songBook3Window:ToggleDescription(); end )
	
	--Show description first in song list checkbox
	self.descFirstCheck = self:CreateCheckBox( "cb_descfirst", self:NextPos(), Main.Settings.DescriptionFirst,
		function(sender, args) songBook3Window:ToggleDescriptionFirst(); end )

	-- Optional C: credit in the song-list description. With the second
	-- checkbox off: Title - Artist (M:SS) - Part; on: Title (M:SS) Artist - Part.
	self.showArtistCheck = self:CreateCheckBox("cb_showartist", self:NextPos(), Main.Settings.ShowArtist,
		function(sender, args)
			songBook3Window:SetShowArtistInDescription(sender:IsChecked());
			self.artistAfterTimeCheck:SetEnabled(sender:IsChecked());
		end )
	self.artistAfterTimeCheck = self:CreateCheckBox("cb_artistaftertime", self:NextPos(), Main.Settings.ArtistAfterTime,
		function(sender, args) songBook3Window:SetArtistAfterTime(sender:IsChecked()); end )
	self.artistAfterTimeCheck:SetEnabled(Main.Settings.ShowArtist == "yes");
	
	--Window visibility on load checkbox
	self.visibleCheck = self:CreateCheckBox( "cb_windowvis", self:NextPos(), Main.Settings.WindowVisible,
		function(sender, args) self:ChangeVisibility(); end )

-- Floating button and timer-window visibility are general display settings.
	self.toggleCheck = self:CreateCheckBox( "cb_iconvis", self:NextPos(20), Main.Settings.ToggleVisible,
		function(sender, args) self:ChangeToggleVisibility(); end, 260 )

	self.toggleOpacityLabel = Turbine.UI.Label();
	self.toggleOpacityLabel:SetParent(self.generalPanel);
	self.toggleOpacityLabel:SetPosition(20,self:NextPos(25));
	self.toggleOpacityLabel:SetWidth(260);
	self.toggleOpacityLabel:SetText(Strings["ui_btn_opacity"]);

	self.toggleOpacityScroll = Turbine.UI.Lotro.ScrollBar();
	self.toggleOpacityScroll:SetParent(self.generalPanel);
	self.toggleOpacityScroll:SetOrientation( Turbine.UI.Orientation.Horizontal );
	self.toggleOpacityScroll:SetPosition(20,self:NextPos(20));
	self.toggleOpacityScroll:SetSize(220,10);
	self.toggleOpacityScroll:SetValue( 100*Main.Settings.ToggleOpacity );
	self.toggleOpacityScroll:SetMaximum( 100 );
	self.toggleOpacityScroll:SetMinimum( 0 );
	self.toggleOpacityScroll:SetSmallChange( 1 );
	self.toggleOpacityScroll:SetLargeChange( 5 );
	self.toggleOpacityScroll:SetBackColor(Turbine.UI.Color(.1,.1,.1));
	self.toggleOpacityScroll.ValueChanged = function(sender,args)
		local newvalue = sender:GetValue()/100;
		Main.Settings.ToggleOpacity = newvalue;
		self.toggleOpacityInd:SetText(tostring(newvalue));
		toggleWindow:SetOpacity(newvalue);
	end

	self.toggleOpacityInd = Turbine.UI.Label();
	self.toggleOpacityInd:SetParent(self.generalPanel);
	self.toggleOpacityInd:SetPosition(250,self.yPos);
	self.toggleOpacityInd:SetWidth(30);
	self.toggleOpacityInd:SetForeColor(Turbine.UI.Color(1,0.77,0.64,0.22));
	self.toggleOpacityInd:SetText(tostring(Main.Settings.ToggleOpacity));

	self.timerWindowVisibleCheck = self:CreateCheckBox( "cb_timerwindowvis", self:NextPos(25), Main.Settings.TimerWindowVisible,
		function(sender, args) songBook3Window:ToggleTimerWindow( sender:IsChecked( ) ); end, 260 )

	-- Band settings -----------------------------
	self.bandLabel = Turbine.UI.Label();
	self.bandLabel:SetParent(self.generalPanel);
	self.bandLabel:SetPosition(20,self:NextPos(20));
	self.bandLabel:SetWidth(260);
	self.bandLabel:SetForeColor(Turbine.UI.Color(1,0.77,0.64,0.22));
	self.bandLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 );
	self.bandLabel:SetText(Strings["ui_band"]);

	-- Dedicated artist search replaces the legacy multi-filter panel.
	self.artistSearchCheck = self:CreateCheckBox("artist_search", self:NextPos(),
		Main.Settings.ArtistSearchVisible,
		function(sender, args) songBook3Window:ShowArtistSearchUI(sender:IsChecked()); end, 145)

	-- Leader mode (uses the party object and enables the sync-start quickslot).
	-- The persisted legacy ChiefMode key is retained so existing settings are preserved.
	self.leaderCheck = self:CreateCheckBox( "cb_leader", self.yPos, Main.Settings.ChiefMode,
		function(sender, args) songBook3Window:SetLeaderMode( sender:IsChecked( ) ); end, 120, 170 )

	-- Countdown timer (if song duration available)
	self.countdownCheck = self:CreateCheckBox( "cb_timerDown", self:NextPos(), Main.Settings.TimerCountdown,
		function(sender, args) songBook3Window.bTimerCountdown = sender:IsChecked( ); end, 120, 170 )
	-- Timer display on/off
	self.timerCheck = self:CreateCheckBox( "cb_timer", self.yPos, Main.Settings.TimerState,
		function(sender, args) self:ToggleTimer( sender:IsChecked( ) ); end, 120 )
	if Main.Settings.TimerState ~= "true" then self.countdownCheck:SetVisible( false ); end

	-- Highlight issues in the ready column (white background).
	self.readyHighlightCheck = self:CreateCheckBox( "cb_rdyColHL", self:NextPos(), Main.Settings.ReadyColHighlight,
		function(sender, args) songBook3Window:HightlightReadyColumns( sender:IsChecked( ) ); end, 120, 170 )
	-- Additional ready-state indicators.
	self.readyColumnCheck = self:CreateCheckBox( "cb_rdyCol", self.yPos, Main.Settings.ReadyColState,
		function(sender, args) self:ToggleReadyCol( sender:IsChecked( ) ); end, 145 )
	if Main.Settings.ReadyColState ~= "true" then self.readyHighlightCheck:SetVisible( false ); end
-- /Band settings ----------------------------

-- earlier edition settings --------------------------

	self.UserChatLabel = Turbine.UI.Label();
	self.UserChatLabel:SetParent(self.generalPanel);
	self.UserChatLabel:SetPosition(300,70);
	self.UserChatLabel:SetWidth(200);
	self.UserChatLabel:SetForeColor(Turbine.UI.Color(1,0.77,0.64,0.22));
	self.UserChatLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 );
	self.UserChatLabel:SetText("User Chat Name");
	
	-- User Chat Name field
	self.UCNameInput = Turbine.UI.Lotro.TextBox();
	self.UCNameInput:SetParent(self.generalPanel);
	self.UCNameInput:SetPosition(300, 90);
	self.UCNameInput:SetSize(230, 20);
	self.UCNameInput:SetFont(Turbine.UI.Lotro.Font.Verdana14);
	self.UCNameInput:SetMultiline(false);
	self.UCNameInput:SetText( Main.Settings.UserChatName );
	self.UCNameInput:SetVisible( true );
	local searchFocus = false; 
	self.UCNameInput.KeyDown = function(sender, args)
		if (args.Action == 162) then
			if (searchFocus) then
				Main.Settings.UserChatName = self.UCNameInput:GetText( );
				songBook3Window:UserChatNameChange( self.UCNameInput:GetText( ) );
			end
		end
	end
	self.UCNameInput.TextChanged = function(sender, args)
		if (searchFocus) then
			Main.Settings.UserChatName = self.UCNameInput:GetText( );
			songBook3Window:UserChatNameChange( self.UCNameInput:GetText( ) );
		end
	end
	self.UCNameInput.FocusGained = function(sender, args)
		searchFocus = true;
	end
	self.UCNameInput.FocusLost = function(sender, args)
		searchFocus = false;
	end
	

	self.ManualChetSelectionLabel = Turbine.UI.Label();
	self.ManualChetSelectionLabel:SetParent(self.generalPanel);
	self.ManualChetSelectionLabel:SetPosition(300,110);
	self.ManualChetSelectionLabel:SetWidth(200);
	self.ManualChetSelectionLabel:SetForeColor(Turbine.UI.Color(1,0.77,0.64,0.22));
	self.ManualChetSelectionLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 );
	self.ManualChetSelectionLabel:SetText("Manual Chat Selection");
	
	--Raid Chat checkbox
	self.RaidChat_CB = Turbine.UI.Lotro.CheckBox();
	self.RaidChat_CB:SetParent(self.generalPanel);
	self.RaidChat_CB:SetPosition(300, 130 );
	self.RaidChat_CB:SetSize(200,20);
	self.RaidChat_CB:SetText(" Raid Chat");
	self.RaidChat_CB:SetChecked(Main.Settings.UseRaidChat == "true" );
	self.RaidChat_CB.CheckedChanged = function(sender, args)
		songBook3Window:ToggleUseRaidChat( sender:IsChecked( ) );
		self.RaidChat_CB:SetChecked( sender:IsChecked( ) );
		
		if sender:IsChecked( ) then
			self.FellowshipChat_CB:SetChecked( false );
			songBook3Window:ToggleUseFellowshipChat( false );
		end
	end
	
	--Fellowship chat checkbox
	self.FellowshipChat_CB = Turbine.UI.Lotro.CheckBox();
	self.FellowshipChat_CB:SetParent(self.generalPanel);
	self.FellowshipChat_CB:SetPosition(300, 150 );
	self.FellowshipChat_CB:SetSize(200,20);
	self.FellowshipChat_CB:SetText(" Fellowship Chat");
	self.FellowshipChat_CB:SetChecked(Main.Settings.UseFellowshipChat == "true" );
	self.FellowshipChat_CB.CheckedChanged = function(sender, args)
		songBook3Window:ToggleUseFellowshipChat( sender:IsChecked( ) );
		
		if sender:IsChecked( ) then
			self.RaidChat_CB:SetChecked( false );
			songBook3Window:ToggleUseRaidChat( false );
		end
	end

	self.AutoTrackPickerLabel = Turbine.UI.Label();
	self.AutoTrackPickerLabel:SetParent(self.generalPanel);
	self.AutoTrackPickerLabel:SetPosition(300,170);
	self.AutoTrackPickerLabel:SetWidth(200);
	self.AutoTrackPickerLabel:SetForeColor(Turbine.UI.Color(1,0.77,0.64,0.22));
	self.AutoTrackPickerLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 );
	self.AutoTrackPickerLabel:SetText("Automatic Part Picking");

	--Automatic track picking based on instrument
	self.AutoPickSongChange_CB = Turbine.UI.Lotro.CheckBox();
	self.AutoPickSongChange_CB:SetParent(self.generalPanel);
	self.AutoPickSongChange_CB:SetPosition(300, 190 );
	self.AutoPickSongChange_CB:SetSize(220,20);
	self.AutoPickSongChange_CB:SetText(" Auto-pick on song change");
	self.AutoPickSongChange_CB:SetChecked(Main.Settings.AutoPickOnSongChange == "true" );
	self.AutoPickSongChange_CB.CheckedChanged = function(sender, args)
		Main.Settings.AutoPickOnSongChange = sender:IsChecked() and "true" or "false";
	end

	--Automatic track picking based on instrument
	self.AutoPickInsChange_CB = Turbine.UI.Lotro.CheckBox();
	self.AutoPickInsChange_CB:SetParent(self.generalPanel);
	self.AutoPickInsChange_CB:SetPosition(300, 210 );
	self.AutoPickInsChange_CB:SetSize(240,20);
	self.AutoPickInsChange_CB:SetText(" Auto-pick on instrument change");
	self.AutoPickInsChange_CB:SetChecked(Main.Settings.AutoPickOnInsChange == "true");
	self.AutoPickInsChange_CB.CheckedChanged = function(sender, args)
		Main.Settings.AutoPickOnInsChange = sender:IsChecked() and "true" or "false";
	end
	
	
	-- Help button
	self.HelpBtn = Turbine.UI.Lotro.Button();
	self.HelpBtn:SetParent(self);
    self.HelpBtn:SetZOrder(30);
	self.HelpBtn:SetPosition(self:GetWidth()-160,self:GetHeight()-35);
	self.HelpBtn:SetSize(100,20);
	self.HelpBtn:SetText("Help");
	
	self.HelpBtn.MouseDown = function(sender,args)
		songBook3Window:ShowHelpWindow();
	end
	
-- /earlier edition settings ----------------------------------------------	

	----------------------------------------------------------------------
	self.instrLabel = Turbine.UI.Label();
	self.instrLabel:SetParent(self.generalPanel);
	self.instrLabel:SetPosition(300,270);
	self.instrLabel:SetWidth(250);
	self.instrLabel:SetForeColor(Turbine.UI.Color(1,0.77,0.64,0.22));
	self.instrLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 );
	self.instrLabel:SetText(Strings["ui_instr"]);
	
	--Instrument bar visibility checkbox
	self.instrCheck = Turbine.UI.Lotro.CheckBox();
	self.instrCheck:SetParent(self.generalPanel);
	self.instrCheck:SetPosition(300, 290 );
	self.instrCheck:SetSize(200,20);
	self.instrCheck:SetText(" " .. Strings["cb_instrvis"]);
	self.instrCheck:SetChecked(Main.CharSettings.InstrSlots[1]["visible"] == "true" or Main.CharSettings.InstrSlots[1]["visible"] == "yes");
	self.instrCheck.CheckedChanged = function(sender, args) songBook3Window:ToggleInstrSlots(); end;
	
	--self.instrCheck = self:CreateCheckBox( "cb_instrvis", self:NextPos(20), Main.CharSettings.InstrSlots[1]["visible"],
		--function(sender, args) songBook3Window:ToggleInstrSlots(); end )
	
	-- clear slots button
	self.clrSlotsBtn = Turbine.UI.Lotro.Button();
	self.clrSlotsBtn:SetParent(self.generalPanel);
	self.clrSlotsBtn:SetPosition(300, 315);
	self.clrSlotsBtn:SetSize(110,20);
	self.clrSlotsBtn:SetText(Strings["ui_clr_slots"]);
	
	self.clrSlotsBtn.MouseDown = function(sender,args)
		songBook3Window:ClearSlots();
	end
	
	
	self.slotsLabel = Turbine.UI.Label();
	self.slotsLabel:SetParent(self.generalPanel);
	self.slotsLabel:SetPosition(300, 345);
	self.slotsLabel:SetWidth(50);
	self.slotsLabel:SetForeColor(Turbine.UI.Color(1,0.77,0.64,0.22));
	self.slotsLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro14 );
	self.slotsLabel:SetText("Slots:");
	
	-- add / remove slots
	self.addSlotBtn = Turbine.UI.Lotro.Button();
	self.addSlotBtn:SetParent(self.generalPanel);
	self.addSlotBtn:SetPosition(350, 345);
	self.addSlotBtn:SetSize(50,20);
	self.addSlotBtn:SetText(Strings["ui_add_slot"]);
	
	self.addSlotBtn.MouseDown = function(sender,args)
		songBook3Window:AddSlot();
	end
	
	self.delSlotBtn = Turbine.UI.Lotro.Button();
	self.delSlotBtn:SetParent(self.generalPanel);
	self.delSlotBtn:SetPosition(410	, 345);
	self.delSlotBtn:SetSize(70,20);
	self.delSlotBtn:SetText(Strings["ui_del_slot"]);
	
	self.delSlotBtn.MouseDown = function(sender,args)
		songBook3Window:DelSlot();
	end	
	
	
	self.rowsLabel = Turbine.UI.Label();
	self.rowsLabel:SetParent(self.generalPanel);
	self.rowsLabel:SetPosition(300, 370);
	self.rowsLabel:SetWidth(50);
	self.rowsLabel:SetForeColor(Turbine.UI.Color(1,0.77,0.64,0.22));
	self.rowsLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro14 );
	self.rowsLabel:SetText("Rows:");
	
	-- add / remove slots rows
	self.addSlotBtn_rows = Turbine.UI.Lotro.Button();
	self.addSlotBtn_rows:SetParent(self.generalPanel);
	self.addSlotBtn_rows:SetPosition(350, 370);
	self.addSlotBtn_rows:SetSize(50,20);
	self.addSlotBtn_rows:SetText(Strings["ui_add_slot"]);
	
	self.addSlotBtn_rows.MouseDown = function(sender,args)
		songBook3Window:AddSlot_row();
	end
	self.delSlotBtn_rows = Turbine.UI.Lotro.Button();
	self.delSlotBtn_rows:SetParent(self.generalPanel);
	self.delSlotBtn_rows:SetPosition(410, 370);
	self.delSlotBtn_rows:SetSize(70,20);
	self.delSlotBtn_rows:SetText(Strings["ui_del_slot"]);
	
	self.delSlotBtn_rows.MouseDown = function(sender,args)
		songBook3Window:DelSlot_row();
	end	
	
	----------------------------------------------------------------------
	
	
	-- commands label
	self.cmdLabel = Turbine.UI.Label();
	self.cmdLabel:SetParent(self.generalPanel);
	self.cmdLabel:SetPosition(20,self:NextPos(25));
	self.cmdLabel:SetWidth(260);
	self.cmdLabel:SetForeColor(Turbine.UI.Color(1,0.77,0.64,0.22));
	self.cmdLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 );
	self.cmdLabel:SetText(Strings["ui_custom"]);
	
	self.addBtn = Turbine.UI.Lotro.Button();
	self.addBtn:SetParent(self.generalPanel);
	self.addBtn:SetPosition(20,self:NextPos(20));
	self.addBtn:SetSize(85,20);
	self.addBtn:SetText(Strings["ui_cus_add"]);
	
	self.addBtn.MouseDown = function(sender,args)
		if(args.Button == Turbine.UI.MouseButton.Left) then
			self:ShowAddWindow(0);
		end
	end
	
	self.editBtn = Turbine.UI.Lotro.Button();
	self.editBtn:SetParent(self.generalPanel);
	self.editBtn:SetPosition(115,self.yPos);
	self.editBtn:SetSize(70,20);
	self.editBtn:SetText(Strings["ui_cus_edit"]);
	self.editBtn:SetEnabled(false);
	
	self.editBtn.MouseDown = function(sender,args)
		if(args.Button == Turbine.UI.MouseButton.Left) then
			self:ShowAddWindow(sCmd);
		end	
	end
	
	self.delBtn = Turbine.UI.Lotro.Button();
	self.delBtn:SetParent(self.generalPanel);
	self.delBtn:SetPosition(195,self.yPos);
	self.delBtn:SetSize(75,20);
	self.delBtn:SetText(Strings["ui_cus_del"]);
	self.delBtn:SetEnabled(false);
	
	self.delBtn.MouseDown = function(sender,args)
		if(args.Button == Turbine.UI.MouseButton.Left) then
			self.cmdlistBox:RemoveItemAt(sCmd);
			local size = self:CountCmds();
			for i=sCmd,size do
				if (i == size) then
					Main.Settings.Commands[tostring(i)] = nil;
				else					
					Main.Settings.Commands[tostring(i)].Title = Main.Settings.Commands[tostring(i+1)].Title;
					Main.Settings.Commands[tostring(i)].Command = Main.Settings.Commands[tostring(i+1)].Command;
				end
			end
			
			sCmd = 0;
	
			self.editBtn:SetEnabled(false);
			self.delBtn:SetEnabled(false);
		end	
	end
	
	self.listFrame = Turbine.UI.Control();
	self.listFrame:SetParent(self.generalPanel);
	self.listFrame:SetPosition(20, self:NextPos(25));
	self.listFrame:SetSize(self:GetWidth() - 40, 80);
	self.listFrame:SetBackColor(Turbine.UI.Color(1, 0.15, 0.15, 0.15));
	
	self.listFrame.heading = Turbine.UI.Label();
	self.listFrame.heading:SetParent( self.listFrame );
	self.listFrame.heading:SetLeft(0);
	self.listFrame.heading:SetSize(100,13);
	self.listFrame.heading:SetFont( Turbine.UI.Lotro.Font.TrajanPro13 );
	self.listFrame.heading:SetText( Strings["ui_cmds"] );
	
	self.listBg = Turbine.UI.Control();
	self.listBg:SetParent(self.listFrame);
	self.listBg:SetPosition(0,15);
	self.listBg:SetSize(self.listFrame:GetWidth() - 19, self.listFrame:GetHeight() - 19);
	self.listBg:SetBackColor(Turbine.UI.Color(1, 0, 0, 0));
	
	self.cmdlistBox = Turbine.UI.ListBox();
	self.cmdlistBox:SetParent(self.listFrame);
	self.cmdlistBox:SetPosition(5,15);
	self.cmdlistBox:SetSize(self.listFrame:GetWidth() - 23,self.listFrame:GetHeight() - 19);
	
	self:RefreshCmds();
	
	self.cmdScroll = Turbine.UI.Lotro.ScrollBar();
	self.cmdScroll:SetParent(self.generalPanel);
	self.cmdScroll:SetOrientation( Turbine.UI.Orientation.Vertical );	
	self.cmdScroll:SetPosition(self.listFrame:GetLeft() + self.listFrame:GetWidth() -12, self.listFrame:GetTop() + 13);
	self.cmdScroll:SetSize(10,self.cmdlistBox:GetHeight());
	self.cmdScroll:SetValue(0);
	self.cmdlistBox:SetVerticalScrollBar( self.cmdScroll );	
	self.cmdScroll:SetVisible( false );
	
	self.cmdlistBox.SelectedIndexChanged = function(sender,args)
		self:ChangeCmd(sender:GetSelectedIndex());
	end

	-- Checkbox for whether popup window shows up
	self.songPopupCheck = Turbine.UI.Lotro.CheckBox();
	self.songPopupCheck:SetParent(self.generalPanel);
    -- Position this AFTER the growing custom-command list, not at Y=500
    -- (which overlaps that list once additional display options are present).
    self.songPopupCheck:SetPosition(20, self.listFrame:GetTop() + self.listFrame:GetHeight() + 12);
	self.songPopupCheck:SetSize(200,20);
	self.songPopupCheck:SetText("Hide matched songs popup");
	self.songPopupCheck:SetChecked(Main.Settings.hideMatchedSongsPopup == "true" );
	self.songPopupCheck.CheckedChanged = function(sender, args)
		Main.Settings.hideMatchedSongsPopup = sender:IsChecked() and "true" or "false";
	end

    self.lyricsHeading = Turbine.UI.Label();
    self.lyricsHeading:SetParent(self.lyricsPanel);
    self.lyricsHeading:SetPosition(20, 15);
    self.lyricsHeading:SetSize(480, 22);
    self.lyricsHeading:SetFont(Turbine.UI.Lotro.Font.TrajanPro16);
    self.lyricsHeading:SetForeColor(Turbine.UI.Color(1, 0.77, 0.64, 0.22));
    self.lyricsHeading:SetText("Lyrics Performance");

    local function LyricsSettingLabel(text, y)
        local label = Turbine.UI.Label();
        label:SetParent(self.lyricsPanel);
        label:SetPosition(20, y);
        label:SetSize(120, 22);
        label:SetFont(Turbine.UI.Lotro.Font.Verdana14);
        label:SetText(text);
        return label;
    end

    self.lyricsPrefixLabel = LyricsSettingLabel("Prefix", 55);
    self.lyricsPrefixInput = Turbine.UI.Lotro.TextBox();
    self.lyricsPrefixInput:SetParent(self.lyricsPanel);
    self.lyricsPrefixInput:SetPosition(145, 53);
    self.lyricsPrefixInput:SetSize(220, 22);
    self.lyricsPrefixInput:SetFont(Turbine.UI.Lotro.Font.Verdana14);
    self.lyricsPrefixInput:SetMultiline(false);
    self.lyricsPrefixInput:SetText(Main.Settings.LyricsPrefix or "~");
    self.lyricsPrefixInput.TextChanged = function(sender, args)
        Main.Settings.LyricsPrefix = sender:GetText() or "";
        if songBook3Window and songBook3Window.UpdateLyricsSendShortcut then
            songBook3Window:UpdateLyricsSendShortcut();
        end
    end

    self.lyricsCommentPrefixLabel = LyricsSettingLabel("Comment Prefix", 88);
    self.lyricsCommentPrefixInput = Turbine.UI.Lotro.TextBox();
    self.lyricsCommentPrefixInput:SetParent(self.lyricsPanel);
    self.lyricsCommentPrefixInput:SetPosition(145, 86);
    self.lyricsCommentPrefixInput:SetSize(120, 22);
    self.lyricsCommentPrefixInput:SetFont(Turbine.UI.Lotro.Font.Verdana14);
    self.lyricsCommentPrefixInput:SetMultiline(false);
    self.lyricsCommentPrefixInput:SetText(Main.Settings.LyricsCommentPrefix or "%");
    self.lyricsCommentPrefixInput.TextChanged = function(sender, args)
        Main.Settings.LyricsCommentPrefix = sender:GetText() or "";
        if songBook3Window and songBook3Window.selectedLyricEntry then
            songBook3Window:LoadLyricsEntry(songBook3Window.selectedLyricEntry);
        end
    end

    self.lyricsIgnoreBlankLinesCheck = Turbine.UI.Lotro.CheckBox();
    self.lyricsIgnoreBlankLinesCheck:SetParent(self.lyricsPanel);
    self.lyricsIgnoreBlankLinesCheck:SetPosition(145, 120);
    self.lyricsIgnoreBlankLinesCheck:SetSize(190, 22);
    self.lyricsIgnoreBlankLinesCheck:SetText("Ignore Blank Lines");
    self.lyricsIgnoreBlankLinesCheck:SetChecked(Main.Settings.LyricsIgnoreBlankLines ~= "false");
    self.lyricsIgnoreBlankLinesCheck.CheckedChanged = function(sender, args)
        Main.Settings.LyricsIgnoreBlankLines = sender:IsChecked() and "true" or "false";
        if songBook3Window and songBook3Window.selectedLyricEntry then
            songBook3Window:LoadLyricsEntry(songBook3Window.selectedLyricEntry);
        end
    end

    self.lyricsDelayLabel = LyricsSettingLabel("Delay (seconds)", 154);
    self.lyricsDelayInput = Turbine.UI.Lotro.TextBox();
    self.lyricsDelayInput:SetParent(self.lyricsPanel);
    self.lyricsDelayInput:SetPosition(145, 152);
    self.lyricsDelayInput:SetSize(55, 22);
    self.lyricsDelayInput:SetFont(Turbine.UI.Lotro.Font.Verdana14);
    self.lyricsDelayInput:SetMultiline(false);
    self.lyricsDelayInput:SetText(tostring(Main.Settings.LyricsDelay or "0"));
    self.lyricsDelayInput.TextChanged = function(sender, args)
        local value = tonumber(sender:GetText());
        if not value then value = 0; end
        value = math.max(0, math.min(5, math.floor(value)));
        Main.Settings.LyricsDelay = tostring(value);
        if sender:GetText() ~= tostring(value) then sender:SetText(tostring(value)); end
    end

    self.lyricsPrefixHelp = Turbine.UI.Label();
    self.lyricsPrefixHelp:SetParent(self.lyricsPanel);
    self.lyricsPrefixHelp:SetPosition(20, 188);
    self.lyricsPrefixHelp:SetSize(490, 72);
    self.lyricsPrefixHelp:SetMultiline(true);
    self.lyricsPrefixHelp:SetText("Normal lyric lines are sent to Say with the Prefix added. Leave Prefix empty to send the line as-is. Lines beginning with the Comment Prefix remain visible but cannot be sent. Slash-prefixed lines are sent as commands.");

    self.lyricsLayoutHelp = Turbine.UI.Label();
    self.lyricsLayoutHelp:SetParent(self.lyricsPanel);
    self.lyricsLayoutHelp:SetPosition(20, 270);
    self.lyricsLayoutHelp:SetSize(490, 65);
    self.lyricsLayoutHelp:SetMultiline(true);
    self.lyricsLayoutHelp:SetText("Ignore Blank Lines removes empty rows from the lyric list. When unchecked, blank rows can be sent like other lyric lines. Delay is the pause between sends (0–5 seconds); after sending, SongBook3 automatically selects the next sendable line. The Lyrics window remembers its position, size, and divider positions automatically.");


	function self:ChangeVisibility()
		if (Main.Settings.WindowVisible == "yes") then
			Main.Settings.WindowVisible = "no";			
		else
			Main.Settings.WindowVisible = "yes";
		end
	end
	
	function self:ChangeToggleVisibility()
		if (Main.Settings.ToggleVisible == "yes") then
			Main.Settings.ToggleVisible = "no";
			toggleWindow:SetVisible(false);
		else
			Main.Settings.ToggleVisible = "yes";
			toggleWindow:SetVisible(true);
		end
	end
	
	function self:ToggleTimer( bChecked )
		songBook3Window:ActivateTimer( bChecked )
		self.countdownCheck:SetVisible( bChecked )
	end

	function self:ToggleReadyCol( bChecked )
		songBook3Window:ShowReadyColumns( bChecked )
		self.readyHighlightCheck:SetVisible( bChecked )
	end

	function self:ChangeCmd(cmdId)
		self.editBtn:SetEnabled(true);
		self.delBtn:SetEnabled(true);
		local selectedItem = self.cmdlistBox:GetItem(cmdId);
		sCmd = cmdId;
		self:SetCmdFocus(sCmd);
	end
	
	function self:SetCmdFocus(cmdId)
		for i = 1,self.cmdlistBox:GetItemCount() do
			local item = self.cmdlistBox:GetItem(i);
			if (i == cmdId) then
				item:SetForeColor( Turbine.UI.Color(1, 0.15, 0.95, 0.15) );
			else
				item:SetForeColor( Turbine.UI.Color(1, 1, 1, 1) );
			end
		end		
	end
	
	self.saveBtn = Turbine.UI.Lotro.Button();
	self.saveBtn:SetParent(self);
    self.saveBtn:SetZOrder(30);
	self.saveBtn:SetPosition(self:GetWidth()/2-50,self:GetHeight()-35);
	self.saveBtn:SetSize(100,20);	
	self.saveBtn:SetText(Strings["ui_save"]);
	self.saveBtn.MouseDown = function(sender,args)
		if(args.Button == Turbine.UI.MouseButton.Left) then
            self:RememberSettingsWindowSize();
            songBook3Window:SaveSettings();
            self:SetVisible(false);
		end
	end
	
    -- Remember the original two-column positions before responsive layout.
    -- When the window is narrow, these controls move underneath the General
    -- column so none of them need horizontal scrolling.
    self.rightSettings = {};
    local rightControls = {
        self.UserChatLabel, self.UCNameInput, self.ManualChetSelectionLabel,
        self.RaidChat_CB, self.FellowshipChat_CB, self.AutoTrackPickerLabel,
        self.AutoPickSongChange_CB, self.AutoPickInsChange_CB,
        self.instrLabel, self.instrCheck, self.clrSlotsBtn,
        self.slotsLabel, self.addSlotBtn, self.delSlotBtn,
        self.rowsLabel, self.addSlotBtn_rows, self.delSlotBtn_rows,
    };
    for _, control in ipairs(rightControls) do
        local x, y = control:GetPosition();
        table.insert(self.rightSettings, {control = control, x = x, y = y});
    end

    -- Wheel scrolling also works while the pointer is over normal settings
    -- labels/checkboxes; the command list and opacity slider retain their
    -- own native wheel/drag behaviour.
    local wheelControls = {
        self.genLabel, self.trackCheck, self.searchCheck, self.descCheck,
        self.descFirstCheck, self.showArtistCheck, self.artistAfterTimeCheck,
        self.visibleCheck, self.toggleCheck, self.toggleOpacityLabel,
        self.timerWindowVisibleCheck, self.bandLabel, self.artistSearchCheck,
        self.leaderCheck, self.countdownCheck, self.timerCheck,
        self.readyHighlightCheck, self.readyColumnCheck,
        self.UserChatLabel, self.ManualChetSelectionLabel,
        self.RaidChat_CB, self.FellowshipChat_CB,
        self.AutoTrackPickerLabel, self.AutoPickSongChange_CB,
        self.AutoPickInsChange_CB, self.instrLabel, self.instrCheck,
        self.cmdLabel, self.songPopupCheck,
    };
    for _, control in ipairs(wheelControls) do
        control.MouseWheel = function(sender, args)
            self:ScrollSettingsPane(false, args.Direction);
        end;
    end

    self.settingsResizeGrip = Main.SongBook3AttachResizeGrip(self, 345, 275,
        function() self:LayoutSettingsWindow(); end,
        function()
            self:RememberSettingsWindowSize();
            songBook3Window:SaveSettings();
        end);
    -- The shared resize helper supplies the drag target; this indicator
    -- makes the otherwise transparent corner handle discoverable.
    self.settingsResizeHint = Turbine.UI.Label();
    self.settingsResizeHint:SetParent(self);
    self.settingsResizeHint:SetSize(18, 18);
    self.settingsResizeHint:SetText("///");
    self.settingsResizeHint:SetForeColor(Turbine.UI.Color(1, 0.70, 0.60, 0.40));
    self.settingsResizeHint:SetMouseVisible(false);
    self.settingsResizeHint:SetZOrder(221);
    self:LayoutSettingsWindow();

    self.Closed = function(sender, args)
        self:RememberSettingsWindowSize();
        if songBook3Window and songBook3Window.SaveSettings then songBook3Window:SaveSettings(); end
        self:SetVisible(false);
    end;

    self:ShowTab("General");

	function self:ShowAddWindow(cmdId)		
		self.addWindow = Turbine.UI.Lotro.Window();
		self.addWindow:SetPosition( self:GetLeft() - 50, self:GetTop() + 50);
		self.addWindow:SetSize( 315, 300 );
		self.addWindow:SetZOrder(21);
		self.addWindow:SetVisible(true);
		
		if (cmdId == 0) then
			self.addWindow:SetText(Strings["ui_cus_winadd"]);
		else
			self.addWindow:SetText(Strings["ui_cus_winedit"]);
		end

		--title label
		self.addWindow.titleLabel = Turbine.UI.Label();
		self.addWindow.titleLabel:SetParent(self.addWindow);
		self.addWindow.titleLabel:SetPosition(20,45);
		self.addWindow.titleLabel:SetSize(100,20);
		self.addWindow.titleLabel:SetFont(Turbine.UI.Lotro.Font.Verdana14);
		self.addWindow.titleLabel:SetText(Strings["ui_cus_title"]);
		
		--text input for command title
		self.addWindow.titleInput = Turbine.UI.Lotro.TextBox();
		self.addWindow.titleInput:SetParent(self.addWindow);
		self.addWindow.titleInput:SetPosition(20,60);
		self.addWindow.titleInput:SetSize(270,20);
		self.addWindow.titleInput:SetMultiline(false);
		self.addWindow.titleInput:SetFont(Turbine.UI.Lotro.Font.Verdana14);
		if (cmdId == 0) then
			self.addWindow.titleInput:SetText("");			
		else
			self.addWindow.titleInput:SetText(Main.Settings.Commands[tostring(cmdId)].Title);
		end
		
		--title label
		self.addWindow.editLabel = Turbine.UI.Label();
		self.addWindow.editLabel:SetParent(self.addWindow);
		self.addWindow.editLabel:SetPosition(20,85);
		self.addWindow.editLabel:SetSize(100,20);
		self.addWindow.editLabel:SetFont(Turbine.UI.Lotro.Font.Verdana14);
		self.addWindow.editLabel:SetText(Strings["ui_cus_command"]);
		
		--text input for command title
		self.addWindow.editInput = Turbine.UI.Lotro.TextBox();
		self.addWindow.editInput:SetParent(self.addWindow);
		self.addWindow.editInput:SetPosition(20,100);
		self.addWindow.editInput:SetSize(270,20);
		self.addWindow.editInput:SetMultiline(false);
		self.addWindow.editInput:SetFont(Turbine.UI.Lotro.Font.Verdana14);
		if (cmdId == 0) then
			self.addWindow.editInput:SetText("");			
		else
			self.addWindow.editInput:SetText(Main.Settings.Commands[tostring(cmdId)].Command);
		end

		--ok button for saving
		self.addWindow.okBtn = Turbine.UI.Lotro.Button();
		self.addWindow.okBtn:SetParent(self.addWindow);
		self.addWindow.okBtn:SetPosition(20,130);
		self.addWindow.okBtn:SetSize(100,20);
		self.addWindow.okBtn:SetText(Strings["ui_ok"]);
		
		self.addWindow.error = Turbine.UI.Label();
		self.addWindow.error:SetParent(self.addWindow);
		self.addWindow.error:SetPosition(20,260);
		self.addWindow.error:SetSize(280,50);
		self.addWindow.error:SetForeColor(Turbine.UI.Color(1,1,0,0));
		self.addWindow.error:SetText("");
		
		
		self.addWindow.okBtn.MouseDown = function(sender,args)
			if(args.Button == Turbine.UI.MouseButton.Left) then
				if (self.addWindow.titleInput:GetText() ~= "" and self.addWindow.editInput:GetText() ~= "") then
					if (cmdId == 0) then
						newId = tostring(self:CountCmds()+1);
						Main.Settings.Commands[newId] = {};
						Main.Settings.Commands[newId].Title = self.addWindow.titleInput:GetText();	
						Main.Settings.Commands[newId].Command = self.addWindow.editInput:GetText();					
					else
						cmdId = tostring(cmdId);
						Main.Settings.Commands[tostring(cmdId)].Title = self.addWindow.titleInput:GetText();					
						Main.Settings.Commands[tostring(cmdId)].Command = self.addWindow.editInput:GetText();					
					end
					
					self.addWindow.error:SetText("");
					self.addWindow:Close();		
					self:RefreshCmds();		
				else
					self.addWindow.error:SetText(Strings["ui_cus_err"]);
				end
			end
		end
		
		
		--cancel button		
		self.addWindow.cancelBtn = Turbine.UI.Lotro.Button();
		self.addWindow.cancelBtn:SetParent(self.addWindow);
		self.addWindow.cancelBtn:SetPosition(150,130);
		self.addWindow.cancelBtn:SetSize(100,20);
		self.addWindow.cancelBtn:SetText(Strings["ui_cancel"]);
		
		self.addWindow.cancelBtn.MouseDown = function(sender,args)
			if(args.Button == Turbine.UI.MouseButton.Left) then
				self.addWindow.error:SetText("");
				self.addWindow:Close();
			end
		end
		
		self.addWindow.help = Turbine.UI.Label();
		self.addWindow.help:SetParent(self.addWindow);
		self.addWindow.help:SetPosition(20,170);
		self.addWindow.help:SetSize(300, 200);
		self.addWindow.help:SetFont(Turbine.UI.Lotro.Font.Verdana14);
		self.addWindow.help:SetText(Strings["ui_cus_help"]);
		
	end
	
end

function SettingsWindow:RefreshCmds()
	local size = self.cmdlistBox:GetItemCount();	
	self.cmdlistBox:ClearItems();
	
	for i=1,self:CountCmds() do
		local cmdItem = Turbine.UI.Label();
		cmdItem:SetText(Main.Settings.Commands[tostring(i)].Title);		
		cmdItem:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft );
		cmdItem:SetSize( 1000, 20 );				
		self.cmdlistBox:AddItem( cmdItem );	
	end
	sCmd = 0;
	
	self.editBtn:SetEnabled(false);
	self.delBtn:SetEnabled(false);
end

function SettingsWindow:CountCmds()
	local cSize = 0;
	for k, v in pairs(Main.Settings.Commands) do 
		cSize = cSize + 1;
	end
	return cSize;
end

--

-- The main song-list settings use a vertical scrolling viewport. Preserve
-- the original two-column arrangement at normal widths; stack the right
-- column beneath the left one in smaller game windows.
function SettingsWindow:LayoutSettingsWindow()
    if not self.rightSettings then return; end
    local width, height = self:GetSize();
    local viewportWidth = math.max(290, width - 28);
    local viewportHeight = math.max(120, height - 120);
    self.generalViewport:SetSize(viewportWidth, viewportHeight);
    self.lyricsViewport:SetSize(viewportWidth, viewportHeight);
    self.generalScrollbar:SetPosition(width - 18, 70);
    self.lyricsScrollbar:SetPosition(width - 18, 70);
    self.generalScrollbar:SetSize(10, viewportHeight);
    self.lyricsScrollbar:SetSize(10, viewportHeight);

    local leftEnd = self.songPopupCheck:GetTop() + self.songPopupCheck:GetHeight();
    local narrow = width < 565;
    local rightEnd = 0;
    for _, entry in ipairs(self.rightSettings) do
        local x, y;
        if narrow then
            -- Original right-hand positions are relative to x=300, y=70.
            x = entry.x - 280;
            y = leftEnd + 30 + entry.y - 70;
        else
            x, y = entry.x, entry.y;
        end
        entry.control:SetPosition(x, y);
        rightEnd = math.max(rightEnd, y + entry.control:GetHeight());
    end

    -- The custom-command list is wide in both layouts, with its own
    -- independent scrollbar. Resizing must reposition its children too.
    local listWidth = math.max(250, viewportWidth - 34);
    self.listFrame:SetWidth(listWidth);
    self.listBg:SetWidth(listWidth - 19);
    self.cmdlistBox:SetWidth(listWidth - 23);
    self.cmdScroll:SetLeft(self.listFrame:GetLeft() + listWidth - 12);
    self.cmdScroll:SetTop(self.listFrame:GetTop() + 13);

    local generalContentHeight = math.max(leftEnd, rightEnd) + 25;
    self.generalPanel:SetSize(viewportWidth, generalContentHeight);
    local generalMax = math.max(0, generalContentHeight - 65 - viewportHeight);
    self.generalScrollbar:SetMaximum(generalMax);
    self.generalScrollbar:SetLargeChange(math.max(30, viewportHeight - 30));
    if self.generalScrollbar:GetValue() > generalMax then
        self.generalScrollbar:SetValue(generalMax);
    end
    self.generalPanel:SetTop(-65 - self.generalScrollbar:GetValue());
    self.generalScrollMaximum = generalMax;

    -- Lyrics has much less content, but should remain scrollable when the
    -- settings window is shorter than the text on this tab.
    self.lyricsHeading:SetWidth(viewportWidth - 35);
    self.lyricsPrefixHelp:SetWidth(viewportWidth - 35);
    self.lyricsLayoutHelp:SetWidth(viewportWidth - 35);
    self.lyricsPrefixInput:SetWidth(math.max(110, math.min(220, viewportWidth - 165)));
    self.lyricsCommentPrefixInput:SetWidth(math.max(90, math.min(120, viewportWidth - 165)));
    if narrow then
        self.lyricsPrefixHelp:SetHeight(123);
        self.lyricsLayoutHelp:SetTop(325);
        self.lyricsLayoutHelp:SetHeight(145);
    else
        self.lyricsPrefixHelp:SetHeight(72);
        self.lyricsLayoutHelp:SetTop(270);
        self.lyricsLayoutHelp:SetHeight(65);
    end
    local lyricsContentHeight = self.lyricsLayoutHelp:GetTop()
        + self.lyricsLayoutHelp:GetHeight() + 20;
    self.lyricsPanel:SetSize(viewportWidth, lyricsContentHeight);
    local lyricsMax = math.max(0, lyricsContentHeight - viewportHeight);
    self.lyricsScrollbar:SetMaximum(lyricsMax);
    self.lyricsScrollbar:SetLargeChange(math.max(30, viewportHeight - 30));
    if self.lyricsScrollbar:GetValue() > lyricsMax then
        self.lyricsScrollbar:SetValue(lyricsMax);
    end
    self.lyricsPanel:SetTop(-self.lyricsScrollbar:GetValue());
    self.lyricsScrollMaximum = lyricsMax;

    if width < 465 then
        -- Keep both footer buttons separate on compact windows.
        local leftButton = math.floor(width / 2) - 110;
        self.saveBtn:SetPosition(leftButton, height - 35);
        self.HelpBtn:SetPosition(leftButton + 120, height - 35);
    else
        self.saveBtn:SetPosition(math.floor(width / 2) - 50, height - 35);
        self.HelpBtn:SetPosition(width - 160, height - 35);
    end
    self.settingsResizeHint:SetPosition(width - 19, height - 18);
    -- Footer buttons, tabs and scrollbar remain outside the moving content.
    self:ShowTab(self.currentSettingsTab or "General");
end

function SettingsWindow:ScrollSettingsPane(isLyrics, direction)
    local scrollbar = isLyrics and self.lyricsScrollbar or self.generalScrollbar;
    local maximum = isLyrics and self.lyricsScrollMaximum or self.generalScrollMaximum;
    if not scrollbar or not maximum or maximum <= 0 then return; end
    local nextValue = scrollbar:GetValue() - (direction or 0) * 44;
    scrollbar:SetValue(math.max(0, math.min(maximum, nextValue)));
end

function SettingsWindow:RememberSettingsWindowSize()
    Main.Settings.SubWindowSizes = Main.Settings.SubWindowSizes or {};
    Main.Settings.SubWindowSizes.Settings = {
        Width = tostring(self:GetWidth()),
        Height = tostring(self:GetHeight()),
    };
end

function SettingsWindow:ShowTab(tabName)
    self.currentSettingsTab = tabName;
    local showLyrics = tabName == "Lyrics";
    self.generalViewport:SetVisible(not showLyrics);
    self.lyricsViewport:SetVisible(showLyrics);
    self.generalScrollbar:SetVisible(not showLyrics and (self.generalScrollMaximum or 0) > 0);
    self.lyricsScrollbar:SetVisible(showLyrics and (self.lyricsScrollMaximum or 0) > 0);
    self.generalTabButton:SetEnabled(showLyrics);
    self.lyricsTabButton:SetEnabled(not showLyrics);
end

function SettingsWindow:Activated(sender, args)
	
	local width, height = self:GetSize();
	local left , top    = self:GetPosition();
	local displayWidth, displayHeight = Turbine.UI.Display.GetSize();
	
	local changeFlag = 0;
	-- Fix to prevent window to travel outside of the screen
	if left + width > displayWidth then
		left = displayWidth - width;
		changeFlag = 1;
	end
	if top + height > displayHeight then
		top = displayHeight - height;
		changeFlag = 1;
	end
	if left < 0 then
		left = 0;
		changeFlag = 1;
	end
	if top < 0 then
		top = 0;
		changeFlag = 1;
	end	
	
	Main.Settings.WindowPosition.Left = left;
	Main.Settings.WindowPosition.Top = top;
		
	if changeFlag == 1 then
		self:SetPosition( left, top );
	end
end

--
