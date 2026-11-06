import "Turbine.UI";
import "Turbine.UI.Lotro";
import "Turbine.Gameplay" -- needed for access to party object

-- SongBook3 is installed as an independent plugin package.
gPlugin = "/songbook3"
gDir = "Sinduriel/SongBook3/"
gSettings = "SongBook3Settings"

import "Sinduriel.SongBook3.Class"; -- Turbine library included so that there are no outside dependencies
import "Sinduriel.SongBook3.SongBook3Lang"; -- Localized LOTRO commands, UI strings, and chat patterns
import "Sinduriel.SongBook3";

local Main = Sinduriel.SongBook3.Windows.Main;

songBook3Window = Sinduriel.SongBook3.Windows.Main.SongBook3Window();
if (Main.Settings.WindowVisible == "yes") then
	songBook3Window:SetVisible( true );
else
	songBook3Window:SetVisible( false );
end
settingsWindow = Sinduriel.SongBook3.Windows.Main.SettingsWindow();
settingsWindow:SetVisible( false );

toggleWindow = Sinduriel.SongBook3.Windows.Main.ToggleWindow();
if (Main.Settings.ToggleVisible == "yes") then
	toggleWindow:SetVisible( true );
else 
	toggleWindow:SetVisible( false );
end

songBook3Command = Turbine.ShellCommand();

function songBook3Command:Execute(cmd, args)
	local action = string.lower(tostring(args or ""));
	if ( action == "show" or action == "anzeigen" or action == "afficher" ) then
		songBook3Window:SetVisible( true );
	elseif ( action == "hide" or action == "verstecken" or action == "cacher" ) then
		songBook3Window:SetVisible( false );
	elseif ( action == "toggle" or action == "umschalten" or action == "basculer" ) then
		songBook3Window:SetVisible( not songBook3Window:IsVisible() );
	else
		songBook3Command:GetHelp();
	end
end

function songBook3Command:GetHelp()
	Turbine.Shell.WriteLine( "/songbook3 show: Display the SongBook3 window" );
	Turbine.Shell.WriteLine( "/songbook3 hide: Hide the SongBook3 window" );
	Turbine.Shell.WriteLine( "/songbook3 toggle: Toggle the SongBook3 window" );
end

Turbine.Shell.AddCommand( "songbook3", songBook3Command );
Turbine.Shell.WriteLine("SongBook3 v1.23.2");
