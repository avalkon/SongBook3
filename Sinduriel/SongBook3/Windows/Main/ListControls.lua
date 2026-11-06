-- Shared SongBook3 list controls.
ListBoxScrolled = class(Turbine.UI.ListBox);
ListBoxCharColumn = class(ListBoxScrolled);

-- ListBoxScrolled ----------------------------------------
-- a Listbox with child scrollbar and separator

function ListBoxScrolled:New( scrollWidth, listbox )
	listbox = listbox or ListBoxScrolled( scrollWidth );
	setmetatable( listbox, self );
	self.__index = self;
	return listbox;
end

function ListBoxScrolled:Constructor( scrollWidth )
	Turbine.UI.ListBox.Constructor( self );
	self:SetMouseVisible( true );	
	self.scrollWidth = scrollWidth;
	self:CreateChildScrollbar( scrollWidth );
	self:CreateChildSeparator( scrollWidth );
end

function ListBoxScrolled:CreateChildScrollbar( width )
	self.scrollBar = Turbine.UI.Lotro.ScrollBar( );
	self.scrollBar:SetParent( self:GetParent( ) );
	self.scrollBar:SetOrientation( Turbine.UI.Orientation.Vertical );
	self.scrollBar:SetZOrder( 320 );
	self.scrollBar:SetWidth( width );
	self.scrollBar:SetTop( 0 );
	self.scrollBar:SetValue( 0 );
	self:SetVerticalScrollBar( self.scrollBar );
	self.scrollBar:SetVisible( false );
end

function ListBoxScrolled:CreateChildSeparator( width )
	self.separator = Turbine.UI.Control( );
	self.separator:SetParent( self:GetParent( ) );
	self.separator:SetZOrder( 300 );
	self.separator:SetWidth( width );
	self.separator:SetTop( 0 );
	self.separator:SetBackColor(Turbine.UI.Color(1, 0.15, 0.15, 0.15));
	self.separator:SetVisible( false );
end
	
function ListBoxScrolled:SetLeft( xPos )
	Turbine.UI.ListBox.SetLeft( self, xPos );
	self.scrollBar:SetLeft( xPos + self:GetWidth( ) );
	self.separator:SetLeft( xPos + self:GetWidth( ) );
end
	
function ListBoxScrolled:SetTop( yPos )
	Turbine.UI.ListBox.SetTop( self, yPos );
	self.scrollBar:SetTop( yPos );
	self.separator:SetTop( yPos );
end
	
function ListBoxScrolled:SetPosition( xPos, yPos )
	self:SetLeft( xPos );
	self:SetTop( yPos );
end
	
function ListBoxScrolled:SetWidth( width )
	Turbine.UI.ListBox.SetWidth( self, width );
	self.scrollBar:SetLeft( self:GetLeft( ) + width );
	self.separator:SetLeft( self:GetLeft( ) + width );
end

function ListBoxScrolled:SetHeight( height )
	Turbine.UI.ListBox.SetHeight( self, height );
	self.scrollBar:SetHeight( height );
	self.separator:SetHeight( height );
end

function ListBoxScrolled:SetSize( width, height )
	self:SetWidth( width );
	self:SetHeight( height );
end

function ListBoxScrolled:SetVisible( bVisible )
	Turbine.UI.ListBox.SetVisible( self, bVisible );
	self.separator:SetVisible( bVisible );
	self.scrollBar:SetVisible( bVisible );
	if bVisible then self.scrollBar:SetParent( self:GetParent( ) )
	else self.scrollBar:SetParent( self ); end
end

function ListBoxScrolled:SetParent( parent )
	Turbine.UI.ListBox.SetParent( self, parent );
	self.separator:SetParent( parent );
	self.scrollBar:SetParent( parent );
end

-- /ListBoxScrolled ----------------------------------------


-- ListBoxReadyIndicator ----------------------------------------
-- A scroll listbox with an optional single-char column before the main column

function ListBoxCharColumn:New( scrollWidth, readyColWidth, listbox )
	listbox = listbox or ListBoxCharColumn( scrollWidth, readyColWidth );
	setmetatable( listbox, self );
	self.__index = self;
	return listbox;
end

function ListBoxCharColumn:Constructor( scrollWidth, readyColWidth )
	ListBoxScrolled.Constructor( self, scrollWidth );
	self.readyColWidth = readyColWidth
	self.bShowReadyChars = true
	self.bHighlightReadyCol = true
end

function ListBoxCharColumn:EnableCharColumn( bColumn )
	if self.bShowReadyChars == bColumn then return; end

	self.bShowReadyChars = bColumn
	if ListBoxScrolled.GetItemCount( self ) == 0 then return; end

	local iList
	local itemCount = ListBoxScrolled.GetItemCount( self )
	if bColumn then -- Add a char item before every item in the list
		for iList = 1, itemCount * 2, 2 do
			local chItem = self:CreateCharItem( )
			ListBoxScrolled.InsertItem( self, iList, chItem )
		end
		self:SetMaxItemsPerLine( 2 )
	else -- remove every item with odd index (the char items)
		for iList = 1, itemCount / 2 do
			ListBoxScrolled.RemoveItemAt( self, iList )
		end
		self:SetMaxItemsPerLine( 1 )
	end
end

function ListBoxCharColumn:GetItem( iLine )
	if self.bShowReadyChars then iLine = iLine * 2; end
	return ListBoxScrolled.GetItem( self, iLine )
end

function ListBoxCharColumn:GetCharColumnItem( iLine )
	if not self.bShowReadyChars then return nil; end
	return ListBoxScrolled.GetItem( self, iLine * 2 - 1 )
end

function ListBoxCharColumn:SetColumnChar( iLine, ch, bHighlight )
	local charItem = self:GetCharColumnItem( iLine )
	if charItem then
		self:ApplyHighlight( charItem, bHighlight )
		charItem:SetText( ch )
	end
end

function ListBoxCharColumn:ApplyHighlight( charItem, bHighlight )
	if bHighlight and self.bHighlightReadyCol then
		charItem:SetForeColor( Turbine.UI.Color( 1, 0, 0, 0 ) )
		charItem:SetBackColor( Turbine.UI.Color( 1, 0.7, 0.7, 0.7 ) )
	else
		charItem:SetForeColor( Turbine.UI.Color( 1, 1, 1, 1 ) )
		charItem:SetBackColor( Turbine.UI.Color( 1, 0, 0, 0 ) )
	end
end

function ListBoxCharColumn:GetItemCount( )
	if self.bShowReadyChars then return math.floor( ListBoxScrolled.GetItemCount( self ) / 2 ); end
	return ListBoxScrolled.GetItemCount( self )
end

function ListBoxCharColumn:ClearItems( )
	ListBoxScrolled.ClearItems( self )
	if self.bShowReadyChars then self:SetMaxItemsPerLine( 2 )
	else self:SetMaxItemsPerLine( 1 ); end
	self:SetOrientation( Turbine.UI.Orientation.Horizontal )
end

function ListBoxCharColumn:CreateCharItem( )
	local charItem = Turbine.UI.Label( )
	charItem:SetMultiline( false )
	charItem:SetSize( self.readyColWidth, 20 )
	charItem:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter )
	self:ApplyHighlight( charItem, false )
	return charItem
end

function ListBoxCharColumn:AddItem( item )
	if self.bShowReadyChars then -- add ready indicator (single char in first column)
		local charItem = self:CreateCharItem( )
		ListBoxScrolled.AddItem( self, charItem )			
	end
	ListBoxScrolled.AddItem( self, item )
end

function ListBoxCharColumn:RemoveItemAt( i )
	if self.bShowReadyChars then
		ListBoxScrolled.RemoveItemAt( self, i * 2 )
		ListBoxScrolled.RemoveItemAt( self, i * 2 - 1 )
	else
		ListBoxScrolled.AddItem( self, i )
	end
end

-- /ListBoxReadyIndicator ----------------------------------------
	
	
