-- Legacy sync-detail window retained as a hidden status cache for track markup.
local Main = Sinduriel.SongBook3.Windows.Main;
PlayersSyncInfoWindow = Turbine.UI.Lotro.Window();
--PlayersSyncInfoWindow:SetZOrder(100);
PlayersSyncInfoWindow:SetSize( 400, 300 );
PlayersSyncInfoWindow:SetPosition( Turbine.UI.Display:GetWidth()/2-200, Turbine.UI.Display:GetHeight()/2-150 );
PlayersSyncInfoWindow:SetText( "Tracks Sync Info" );
PlayersSyncInfoWindow:SetVisible( false );
PlayersSyncInfoWindow:SetOpacity(0.9);

SyncInfolistbox = Turbine.UI.ListBox();
SyncInfolistbox:SetParent( PlayersSyncInfoWindow );
--SyncInfolistbox:SetBackColor( Turbine.UI.Color( 0.1, 0.1, 0.1 ) );
SyncInfolistbox:SetPosition( 30, 50 );
SyncInfolistbox:SetSize( PlayersSyncInfoWindow:GetWidth() - 60 , PlayersSyncInfoWindow:GetHeight() - 80  );

scrollBarV = Turbine.UI.Lotro.ScrollBar( );
scrollBarV:SetParent( PlayersSyncInfoWindow );
scrollBarV:SetOrientation( Turbine.UI.Orientation.Vertical );
scrollBarV:SetPosition(SyncInfolistbox:GetLeft() + SyncInfolistbox:GetWidth(), SyncInfolistbox:GetTop());
scrollBarV:SetSize(10,SyncInfolistbox:GetHeight());
scrollBarV:SetBackColor(Turbine.UI.Color(.1,.1,.1));
scrollBarV:SetZOrder( 120 );
scrollBarV:SetValue( 0 );
SyncInfolistbox:SetVerticalScrollBar( scrollBarV );
--scrollBarV:SetVisible( false );

scrollBarH = Turbine.UI.Lotro.ScrollBar( );
scrollBarH:SetParent( PlayersSyncInfoWindow );
scrollBarH:SetOrientation( Turbine.UI.Orientation.Horizontal );
scrollBarH:SetPosition(SyncInfolistbox:GetLeft(),SyncInfolistbox:GetHeight() + SyncInfolistbox:GetTop());
scrollBarH:SetSize(SyncInfolistbox:GetWidth(), 10);
scrollBarH:SetBackColor(Turbine.UI.Color(.1,.1,.1));
scrollBarH:SetZOrder( 120 );
scrollBarH:SetValue( 0 );
SyncInfolistbox:SetHorizontalScrollBar( scrollBarH );
--scrollBarH:SetVisible( false );

-- window resize control
PlayersSyncInfoWindow.resizeCtrl = Turbine.UI.Control();
PlayersSyncInfoWindow.resizeCtrl:SetParent(PlayersSyncInfoWindow);
PlayersSyncInfoWindow.resizeCtrl:SetSize(20,20);		
PlayersSyncInfoWindow.resizeCtrl:SetZOrder(200);
PlayersSyncInfoWindow.resizeCtrl:SetPosition(PlayersSyncInfoWindow:GetWidth() - 20,PlayersSyncInfoWindow:GetHeight() - 20); 
				
PlayersSyncInfoWindow.resizeCtrl.MouseDown = function(sender,args)
  sender.dragStartX = args.X;
  sender.dragStartY = args.Y;
  sender.dragging = true;
end
	
PlayersSyncInfoWindow.resizeCtrl.MouseUp = function(sender,args)
  sender.dragging = false;
  Main.Settings.PlayersSyncInfoWindowPosition.Width = PlayersSyncInfoWindow:GetWidth();
  Main.Settings.PlayersSyncInfoWindowPosition.Height = PlayersSyncInfoWindow:GetHeight();
end

PlayersSyncInfoWindow.resizeCtrl.MouseMove = function(sender,args)
	local width, height = PlayersSyncInfoWindow:GetSize();
	local gameDisplayWidth, gameDisplayHeight = Turbine.UI.Display.GetSize();
	
	if sender.dragging then
		
		width = width + args.X - sender.dragStartX;
		height = height + args.Y - sender.dragStartY;
		local WindowLeft = PlayersSyncInfoWindow:GetLeft();
		local WindowTop  = PlayersSyncInfoWindow:GetTop ();
		
		if width < 300 then width = 300; end
		if height < 200 then height = 200; end
		------------------------------------
		if WindowLeft + width  > gameDisplayWidth  then
		width  = gameDisplayWidth  - WindowLeft; end
		if WindowTop  + height > gameDisplayHeight then
		height = gameDisplayHeight - WindowTop ; end
		------------------------------------
		
		PlayersSyncInfoWindow:SetSize( width, height );
		
		SyncInfolistbox:SetSize( PlayersSyncInfoWindow:GetWidth() - 60 , PlayersSyncInfoWindow:GetHeight() - 80  );
		scrollBarV:SetPosition(SyncInfolistbox:GetLeft() + SyncInfolistbox:GetWidth(), SyncInfolistbox:GetTop());
		scrollBarV:SetSize(10,SyncInfolistbox:GetHeight());
		scrollBarH:SetPosition(SyncInfolistbox:GetLeft(),SyncInfolistbox:GetHeight() + SyncInfolistbox:GetTop());
		scrollBarH:SetSize(SyncInfolistbox:GetWidth(), 10);
	end
	
	sender:SetPosition( PlayersSyncInfoWindow:GetWidth() - sender:GetWidth(), PlayersSyncInfoWindow:GetHeight() - sender:GetHeight() );
end -- resizeCtrl.MouseMove

function PlayersSyncInfoWindow:Activated(sender, args)

	local width, height = self:GetSize();
	local left , top    = self:GetPosition();
	local displayWidth, displayHeight = Turbine.UI.Display.GetSize();
	
	local changeFlag = 0;
	-- Fix to prevent window to travel outside of the screen
	if width + 0 > displayWidth then
		width = displayWidth - 0;
		changeFlag = 1;
	end
	if height + 0 > displayHeight then
		height = displayHeight - 0;
		changeFlag = 1;
	end
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
	
	Main.Settings.PlayersSyncInfoWindowPosition.Left = left;
	Main.Settings.PlayersSyncInfoWindowPosition.Top = top;
	Main.Settings.PlayersSyncInfoWindowPosition.Width = width;
	Main.Settings.PlayersSyncInfoWindowPosition.Height = height;
		
	if changeFlag == 1 then
		self:SetPosition( left, top );
		self:SetSize( width, height );
		self.resizeCtrl:SetPosition(self:GetWidth() - self.resizeCtrl:GetWidth(),self:GetHeight() - self.resizeCtrl:GetHeight());
		SyncInfolistbox:SetSize( self:GetWidth() - 60 , self:GetHeight() - 80  );
		scrollBarV:SetPosition(SyncInfolistbox:GetLeft() + SyncInfolistbox:GetWidth(), SyncInfolistbox:GetTop());
		scrollBarV:SetSize(10,SyncInfolistbox:GetHeight());
		scrollBarH:SetPosition(SyncInfolistbox:GetLeft(),SyncInfolistbox:GetHeight() + SyncInfolistbox:GetTop());
		scrollBarH:SetSize(SyncInfolistbox:GetWidth(), 10);
	end
end
