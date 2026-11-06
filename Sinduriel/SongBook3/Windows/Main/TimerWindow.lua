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

function MainWindowClass:ToggleTimerWindow(State)
    self.TimerWindowVisible = State;
    Timer_Window:SetVisible(self.TimerWindowVisible);
end
