-- Help window and its startup-display behavior.
local Main = Sinduriel.SongBook3.Windows.Main;
local MainWindowClass = Main.SongBook3Window;
Help_Window = Turbine.UI.Lotro.Window();
Help_Window:SetZOrder(100);
Help_Window:SetSize( 410, 500 );
Help_Window:SetPosition( Turbine.UI.Display:GetWidth()/2-205, Turbine.UI.Display:GetHeight()/2-250 );
Help_Window:SetText( "Help" );
Help_Window:SetVisible( false );
Help_Window:SetOpacity(0.9);

Help_Frame = Turbine.UI.Control();
Help_Frame:SetParent(Help_Window);
Help_Frame:SetPosition(5,40);
Help_Frame:SetSize(400,420);
Help_Frame:SetBlendMode( Turbine.UI.BlendMode.AlphaBlend );
Help_Frame:SetBackground(gDir .. "Help_window.tga");

--Help Window display checkbox
Help_Window_CB = Turbine.UI.Lotro.CheckBox();
Help_Window_CB:SetParent( Help_Window );
Help_Window_CB:SetPosition(50, 460 );
Help_Window_CB:SetSize(200,20);
Help_Window_CB:SetText(" Don't Show this again.");
-- The main window constructor applies the saved setting after Settings loads.
Help_Window_CB.CheckedChanged = function(sender, args)
    -- Main.lua assigns songBook3Window only AFTER its constructor returns.
    -- SetChecked may fire during that constructor: do not access nil then.
    if songBook3Window == nil then return; end
    songBook3Window:SetHelpWindowDisabled(sender:IsChecked());
    songBook3Window:SaveSettings();
end;

function MainWindowClass:SetHelpWindowDisabled( State )
	self.HelpWindowDisable = State;
end

function MainWindowClass:ShowHelpWindow( )
	Help_Window:SetVisible(true);
end

function MainWindowClass:HelpWindow( )
	if self.HelpWindowDisable == false and Main.HelpWindow_Load_Flag == 1 then
		Help_Window:SetVisible(true);
	end
	Main.HelpWindow_Load_Flag = 0;
end
