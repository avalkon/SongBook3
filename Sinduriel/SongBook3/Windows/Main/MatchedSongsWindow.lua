-- Matched-song selection popup.
local Main = Sinduriel.SongBook3.Windows.Main;
MatchedSongsWindow = Turbine.UI.Lotro.Window();
MatchedSongsWindow:SetZOrder(100);
MatchedSongsWindow:SetSize( 600, 300 );
MatchedSongsWindow:SetPosition( Turbine.UI.Display:GetWidth()/2-300, Turbine.UI.Display:GetHeight()/2-200 );
MatchedSongsWindow:SetText( "Matched Songs" );
MatchedSongsWindow:SetVisible( false );
MatchedSongsWindow:SetOpacity(0.9);
----------------------------------------------
MatchedSongsListbox = Turbine.UI.ListBox();
MatchedSongsListbox:SetParent( MatchedSongsWindow );
MatchedSongsListbox:SetPosition( 30, 50 );
MatchedSongsListbox:SetSize( MatchedSongsWindow:GetWidth() - 60 , MatchedSongsWindow:GetHeight() - 80  );
----------------------------------------------
MatchedSongsScrollBarV = Turbine.UI.Lotro.ScrollBar( );
MatchedSongsScrollBarV:SetParent( MatchedSongsWindow );
MatchedSongsScrollBarV:SetOrientation( Turbine.UI.Orientation.Vertical );
MatchedSongsScrollBarV:SetPosition(MatchedSongsListbox:GetLeft() + MatchedSongsListbox:GetWidth(), MatchedSongsListbox:GetTop());
MatchedSongsScrollBarV:SetSize(10,MatchedSongsListbox:GetHeight());
MatchedSongsScrollBarV:SetBackColor(Turbine.UI.Color(.1,.1,.1));
MatchedSongsScrollBarV:SetZOrder( 120 );
MatchedSongsScrollBarV:SetValue( 0 );
MatchedSongsListbox:SetVerticalScrollBar( MatchedSongsScrollBarV );
----------------------------------------------
MatchedSongsScrollBarH = Turbine.UI.Lotro.ScrollBar( );
MatchedSongsScrollBarH:SetParent( MatchedSongsWindow );
MatchedSongsScrollBarH:SetOrientation( Turbine.UI.Orientation.Horizontal );
MatchedSongsScrollBarH:SetPosition(MatchedSongsListbox:GetLeft(),MatchedSongsListbox:GetHeight() + MatchedSongsListbox:GetTop());
MatchedSongsScrollBarH:SetSize(MatchedSongsListbox:GetWidth(), 10);
MatchedSongsScrollBarH:SetBackColor(Turbine.UI.Color(.1,.1,.1));
MatchedSongsScrollBarH:SetZOrder( 120 );
MatchedSongsScrollBarH:SetValue( 0 );
MatchedSongsListbox:SetHorizontalScrollBar( MatchedSongsScrollBarH );


-- window resize control
MatchedSongsWindow.resizeCtrl = Turbine.UI.Control();
MatchedSongsWindow.resizeCtrl:SetParent(MatchedSongsWindow);
MatchedSongsWindow.resizeCtrl:SetSize(20,20);		
MatchedSongsWindow.resizeCtrl:SetZOrder(200);
MatchedSongsWindow.resizeCtrl:SetPosition(MatchedSongsWindow:GetWidth() - 20,MatchedSongsWindow:GetHeight() - 20); 
				
MatchedSongsWindow.resizeCtrl.MouseDown = function(sender,args)
  sender.dragStartX = args.X;
  sender.dragStartY = args.Y;
  sender.dragging = true;
end
	
MatchedSongsWindow.resizeCtrl.MouseUp = function(sender,args)
  sender.dragging = false;
  --Main.Settings.PlayersSyncInfoWindowPosition.Width = MatchedSongsWindow:GetWidth();
  --Main.Settings.PlayersSyncInfoWindowPosition.Height = MatchedSongsWindow:GetHeight();
end

MatchedSongsWindow.resizeCtrl.MouseMove = function(sender,args)
	local width, height = MatchedSongsWindow:GetSize();
	local gameDisplayWidth, gameDisplayHeight = Turbine.UI.Display.GetSize();
	
	if sender.dragging then
		
		width = width + args.X - sender.dragStartX;
		height = height + args.Y - sender.dragStartY;
		local WindowLeft = MatchedSongsWindow:GetLeft();
		local WindowTop  = MatchedSongsWindow:GetTop ();
		
		if width < 300 then width = 300; end
		if height < 200 then height = 200; end
		------------------------------------
		if WindowLeft + width  > gameDisplayWidth  then
		width  = gameDisplayWidth  - WindowLeft; end
		if WindowTop  + height > gameDisplayHeight then
		height = gameDisplayHeight - WindowTop ; end
		------------------------------------
		
		MatchedSongsWindow:SetSize( width, height );
		
		MatchedSongsListbox:SetSize( MatchedSongsWindow:GetWidth() - 60 , MatchedSongsWindow:GetHeight() - 80  );
		MatchedSongsScrollBarV:SetPosition(MatchedSongsListbox:GetLeft() + MatchedSongsListbox:GetWidth(), MatchedSongsListbox:GetTop());
		MatchedSongsScrollBarV:SetSize(10,MatchedSongsListbox:GetHeight());
		MatchedSongsScrollBarH:SetPosition(MatchedSongsListbox:GetLeft(),MatchedSongsListbox:GetHeight() + MatchedSongsListbox:GetTop());
		MatchedSongsScrollBarH:SetSize(MatchedSongsListbox:GetWidth(), 10);
	end
	
	sender:SetPosition( MatchedSongsWindow:GetWidth() - sender:GetWidth(), MatchedSongsWindow:GetHeight() - sender:GetHeight() );
end -- resizeCtrl.MouseMove
