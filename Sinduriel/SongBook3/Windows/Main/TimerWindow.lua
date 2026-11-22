-- Floating timer overlay and its visibility control.
local Main = Sinduriel.SongBook3.Windows.Main;
local MainWindowClass = Main.SongBook3Window;
Timer_Window = Turbine.UI.Window();
--Timer_Window:SetBackColor(Turbine.UI.Color(0,0,0,0));
--Timer_Window:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend);
--Timer_Window:SetBackColorBlendMode(Turbine.UI.BlendMode.AlphaBlend);
Timer_Window:SetPosition(50,1);
Timer_Window_Width = 150;
Timer_Window_Height = 94;
Timer_Window:SetSize(Timer_Window_Width,Timer_Window_Height);
Timer_Window:SetOpacity(1);
Timer_Window:SetZOrder(100);
Timer_Window:SetVisible( true );

Timer_Frame = Turbine.UI.Control();
Timer_Frame:SetParent(Timer_Window);
Timer_Frame:SetPosition(0,0);
Timer_Frame:SetSize(150,94);
Timer_Frame:SetBlendMode( Turbine.UI.BlendMode.AlphaBlend );
Timer_Frame:SetBackground(gDir .. "SongBook3Timer.tga");

Timer_Label = Turbine.UI.Label( );
Timer_Label:SetParent(Timer_Window);
Timer_Label:SetMultiline( false );
Timer_Label:SetSize(150,40);
Timer_Label:SetPosition( 0, 9 );
Timer_Label:SetFont( Turbine.UI.Lotro.Font.BookAntiquaBold24 );
Timer_Label:SetForeColor( Turbine.UI.Color( 1, 0, 0, 0 ) );
Timer_Label:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter );
Timer_Label:SetZOrder( 100 );
Timer_Label:SetVisible( true );
Timer_Label:SetText( "0:00" );

Song_Label = Turbine.UI.Label( );
Song_Label:SetParent(Timer_Window);
--Song_Label:SetMultiline( false );
Song_Label:SetSize(119,40);
Song_Label:SetPosition( 17, 37 );
Song_Label:SetFont( Turbine.UI.Lotro.Font.BookAntiquaBold18 );
Song_Label:SetForeColor( Turbine.UI.Color( 1, 0, 0, 0 ) );
Song_Label:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft );
Song_Label:SetZOrder( 100 );
Song_Label:SetVisible( true );
--Song_Label:SetText( "Song" );

Click_Label = Turbine.UI.Label( );
Click_Label:SetParent(Timer_Window);
Click_Label:SetSize(150,94);
Click_Label:SetPosition( 0, 0 );
Click_Label:SetZOrder( 100 );
Click_Label:SetVisible( true );

Click_Label.MouseEnter = function(sender,args)
	--Timer_Frame:SetBackground(gDir .. "toggle_hover.tga");
	Timer_Window:SetOpacity(0.9);
end
Click_Label.MouseLeave = function(sender,args)
	--Timer_Frame:SetBackground(gDir .. "toggle.tga");
	Timer_Window:SetOpacity(1);
end		
Click_Label.MouseDown = function( sender, args )
	if(args.Button == Turbine.UI.MouseButton.Left) then
		sender.dragStartX = args.X;
		sender.dragStartY = args.Y;
		sender.dragging = true;
		sender.dragged = false;
		Timer_Window:SetBackColor( Turbine.UI.Color(0,0,1,0) );
	end
end
Click_Label.MouseUp = function( sender, args ) 
	if (args.Button == Turbine.UI.MouseButton.Left) then			
		if (sender.dragging) then
			sender.dragging = false;
		end
		if not sender.dragged then
            -- Keep the floating timer and main toggle icon visible while hiding
            -- the rest of the SongBook3 workspace. Clicking the timer again,
            -- or clicking the icon, restores the previous window visibility.
            songBook3Window:ToggleAllWindows(true);
		end
		Timer_Window:SetBackColor( Turbine.UI.Color(0,0,0,0) );
		Main.Settings.ToggleLeft = Timer_Window:GetLeft();
		Main.Settings.ToggleTop = Timer_Window:GetTop();			
	end
end
Click_Label.MouseMove = function(sender,args)
	if ( sender.dragging ) then
		local left, top = Timer_Window:GetPosition();
		Timer_Window:SetPosition( left + ( args.X - sender.dragStartX ), top + args.Y - sender.dragStartY );
		sender:SetPosition( 0, 0 );
		sender.dragged = true;
		-- checks to restrict moving outside the screen space
		if (Timer_Window:GetLeft() > Turbine.UI.Display.GetWidth() - 150) then
			Timer_Window:SetLeft(Turbine.UI.Display.GetWidth() - 150);				
		end
		if (Timer_Window:GetLeft() < 0) then
			Timer_Window:SetLeft(0);				
		end			
		if (Timer_Window:GetTop() > Turbine.UI.Display.GetHeight() - 94) then
			Timer_Window:SetTop(Turbine.UI.Display.GetHeight() - 94);				
		end
		if (Timer_Window:GetTop() < 0) then
			Timer_Window:SetTop(0);				
		end	
		
		Main.Settings.Timer_WindowPosition.Left = Timer_Window:GetLeft();
		Main.Settings.Timer_WindowPosition.Top  = Timer_Window:GetTop();
	end
end

-- Keep the user's preference separate from the overlay's effective visibility.
function MainWindowClass:RefreshTimerWindowVisibility()
    local visible = self.TimerWindowVisible == true
        and (not self.TimerMusicModeOnly or self.timerInMusicMode == true)
        and not self.timerHiddenByHUD and not self.timerHiddenByCollapse;
    Timer_Window:SetVisible(visible);
end

function MainWindowClass:ToggleTimerWindow(State)
    self.TimerWindowVisible = State == true;
    Main.Settings.TimerWindowVisible = tostring(self.TimerWindowVisible);
    self:RefreshTimerWindowVisibility();
end

-- Both images have the same native dimensions; change only the frame.
function MainWindowClass:SetLegacyTimerWindow(state)
    self.UseLegacyTimerWindow = state == true;
    Main.Settings.UseLegacyTimerWindow = tostring(self.UseLegacyTimerWindow);
    local image = self.UseLegacyTimerWindow and "SongbookTimer.tga" or "SongBook3Timer.tga";
    Timer_Frame:SetBackground(gDir .. image);
end

function MainWindowClass:SetTimerMusicModeOnly(state)
    self.TimerMusicModeOnly = state == true;
    Main.Settings.TimerMusicModeOnly = tostring(self.TimerMusicModeOnly);
    self:RefreshTimerWindowVisibility();
end

-- LOTRO does not document a readable music-mode flag. Track observed
-- transitions for this session only; never use this estimate for playback.
function MainWindowClass:SetObservedMusicMode(state)
    local changed = self.timerInMusicMode ~= (state == true);
    self.timerInMusicMode = state == true;
    if type(conductorBridgeOnMusicModeChanged) == "function" then conductorBridgeOnMusicModeChanged(); end;
    if self.TimerMusicModeOnly then self:RefreshTimerWindowVisibility(); end
end

function MainWindowClass:ObserveMusicModeToggle()
    if self.timerInMusicMode then
        self:SetObservedMusicMode(false);
        return;
    end
    -- A music-mode request without an equipped instrument cannot succeed.
    local player = Turbine.Gameplay.LocalPlayer:GetInstance();
    local equipment = player and player:GetEquipment();
    if not equipment or not equipment:GetItem(Turbine.Gameplay.Equipment.Instrument) then return; end
    if player.IsInCombat and player:IsInCombat() then return; end
    self:SetObservedMusicMode(true);
end

function MainWindowClass:ObserveMusicModeAction(action)
    -- Community-documented LOTRO action IDs: toggle and music note actions.
    -- KeyUp avoids repeated toggles if the key is held down.
    if action == 268435683 then
        self:ObserveMusicModeToggle();
    elseif type(action) == "number" and action >= 268435646 and action <= 268435682 then
        self:SetObservedMusicMode(true);
    end
end

function MainWindowClass:ObserveMusicModeChat(args)
    if args.ChatType ~= Turbine.ChatType.Standard and args.ChatType ~= Turbine.ChatType.Error then return; end
    local msg = args.Message;
    if type(msg) ~= "string" then return; end
    local text = string.lower(msg);
    if args.ChatType == Turbine.ChatType.Standard then
        -- Existing localized self-only readiness/play notifications are
        -- positive evidence even when music mode was entered outside SongBook3.
        local begin = Strings["chat_playBeginSelf"];
        local ready = Strings["chat_playSelfReadyMsg"];
        if (begin and begin ~= "" and string.find(msg, begin, 1, true) == 1)
            or (ready and ready ~= "" and string.find(msg, "^" .. ready)) then
            self:SetObservedMusicMode(true);
            return;
        end
        -- Some clients may expose explicit mode notifications. Match only
        -- self-directed messages, never player chat or another player's sync.
        if string.match(text, "^you enter music mode[%.!]?$" ) or
           string.match(text, "^you have entered music mode[%.!]?$" ) or
           string.match(text, "^you are now in music mode[%.!]?$" ) then
            self:SetObservedMusicMode(true);
        elseif string.match(text, "^you leave music mode[%.!]?$" ) or
               string.match(text, "^you have left music mode[%.!]?$" ) or
               string.match(text, "^you are no longer in music mode[%.!]?$" ) or
               string.match(text, "^you exit music mode[%.!]?$" ) then
            self:SetObservedMusicMode(false);
        end
    elseif string.find(text, "not in music mode", 1, true) or
           string.find(text, "cannot enter music mode", 1, true) or
           string.find(text, "can't enter music mode", 1, true) then
        self:SetObservedMusicMode(false);
    end
end
