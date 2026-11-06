local Main = Sinduriel.SongBook3.Windows.Main;
local MainWindowClass = Main.SongBook3Window;

ToggleWindow = class( Turbine.UI.Window );

function ToggleWindow:Constructor()
	Turbine.UI.Window.Constructor( self );
	
	-- legacy fix
	if not (Main.Settings.ToggleVisible) then
		Main.Settings.ToggleVisible = "yes";		
		Main.Settings.ToggleLeft = tostring(Turbine.UI.Display.GetWidth()-55);
		Main.Settings.ToggleTop = "310";
	end	
	
	self:SetPosition( Main.Settings.ToggleLeft, Main.Settings.ToggleTop );
	self:SetSize(35,35);
	self:SetZOrder(70);	
	self:SetVisible( true );
	
	self:SetOpacity(Main.Settings.ToggleOpacity);
	
	self.button = Turbine.UI.Control();
	self.button:SetParent(self);
	self.button:SetPosition(0,0);
	self.button:SetSize(35,35);
	self.button:SetBlendMode( Turbine.UI.BlendMode.AlphaBlend );
	self.button:SetBackground(gDir .. "toggle.tga");
	self.button.MouseEnter = function(sender,args)
		self.button:SetBackground(gDir .. "toggle_hover.tga");
		self:SetOpacity(0.9);
	end
	self.button.MouseLeave = function(sender,args)
		self.button:SetBackground(gDir .. "toggle.tga");
		self:SetOpacity(Main.Settings.ToggleOpacity);
	end		
	self.button.MouseDown = function( sender, args )
		if(args.Button == Turbine.UI.MouseButton.Left) then
			sender.dragStartX = args.X;
			sender.dragStartY = args.Y;
			sender.dragging = true;
			sender.dragged = false;
			self:SetBackColor( Turbine.UI.Color(0,0,1,0) );
		end
	end
	self.button.MouseUp = function( sender, args ) 
		if (args.Button == Turbine.UI.MouseButton.Left) then			
			if (sender.dragging) then
				sender.dragging = false;
			end
			if not sender.dragged then
				songBook3Window:ToggleAllWindows();
			end
			self:SetBackColor( Turbine.UI.Color(0,0,0,0) );
			Main.Settings.ToggleLeft = self:GetLeft();
			Main.Settings.ToggleTop = self:GetTop();			
		end
	end
	self.button.MouseMove = function(sender,args)
		if ( sender.dragging ) then
			local left, top = self:GetPosition();
			self:SetPosition( left + ( args.X - sender.dragStartX ), top + args.Y - sender.dragStartY );
			sender:SetPosition( 0, 0 );
			sender.dragged = true;
			-- checks to restrict moving outside the screen space
			if (self:GetLeft() > Turbine.UI.Display.GetWidth() - 35) then
				self:SetLeft(Turbine.UI.Display.GetWidth() - 35);				
			end
			if (self:GetLeft() < 0) then
				self:SetLeft(0);				
			end			
			if (self:GetTop() > Turbine.UI.Display.GetHeight() - 35) then
				self:SetTop(Turbine.UI.Display.GetHeight() - 35);				
			end
			if (self:GetTop() < 0) then
				self:SetTop(0);				
			end			
		end
	end
end

function MainWindowClass:ToggleAllWindows(keepTimerVisible)
    -- The timer and icon can both collapse the auxiliary workspace. They share
    -- one visibility snapshot so either control can restore the same windows.
    if self.pluginWindowsCollapsed then
        local previous = self.pluginWindowVisibilityBeforeCollapse or {};
        self.pluginWindowsCollapsed = false;
        self.pluginWindowVisibilityBeforeCollapse = nil;
        for _, state in ipairs(previous) do
            if state.window then
                state.window:SetVisible(state.visible);
                if state.visible and state.window.Activate then
                    state.window:Activate();
                end
            end
        end
        if self:IsVisible() then self:HelpWindow(); end
        return;
    end

    local timerWindow = Sinduriel.SongBook3.Windows.Main.Timer_Window;
    local windows = { self };
    local function addWindow(window)
        if window then windows[#windows + 1] = window; end
    end
    addWindow(settingsWindow);
    addWindow(Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow);
    -- The timer is omitted when the click originated on the timer itself.
    if not keepTimerVisible then addWindow(timerWindow); end
    addWindow(Sinduriel.SongBook3.Windows.Main.MatchedSongsWindow);
    addWindow(Sinduriel.SongBook3.Windows.Main.Help_Window);
    addWindow(self.setlistWindow);
    addWindow(self.setlistShareWindow);
    addWindow(self.receivedSetlistWindow);
    addWindow(self.readyCheckWindow);
    addWindow(self.lyricsWindow);
    local previous = {};
    local hasUserWindowVisible = false;
    for _, window in ipairs(windows) do
        if window then
            local visible = window:IsVisible();
            previous[#previous + 1] = { window = window, visible = visible };
            if window ~= timerWindow and visible then
                hasUserWindowVisible = true;
            end
        end
    end

    -- A timer click only collapses the workspace; it must not open the main
    -- window merely because the timer is the only visible plugin window.
    -- The icon retains its established behaviour in that situation.
    if not hasUserWindowVisible then
        if not keepTimerVisible then
            self:SetVisible(true);
            self:Activate();
            self:HelpWindow();
        end
        return;
    end

    self.pluginWindowVisibilityBeforeCollapse = previous;
    self.pluginWindowsCollapsed = true;
    for _, state in ipairs(previous) do
        state.window:SetVisible(false);
    end
end
