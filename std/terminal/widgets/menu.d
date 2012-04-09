/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Nov 25, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/terminal/widgets/_menu.d)
 */
module std.terminal.widgets.menu;

import std.event;

import std.terminal.application;
import std.terminal.event;

import std.terminal.geometry.orientation;
import std.terminal.geometry.point;
import std.terminal.geometry.rect;
import std.terminal.geometry.size;

import std.terminal.widgets.composite;
import std.terminal.widgets.control;
import std.terminal.widgets.terminal;

class MenuItem : Composite
{
    Menu parentMenu;
}

class Menu : Composite
{
    alias Control.bounds bounds;
    alias Control.hasBorder hasBorder;
    
    /// This event is raised when the receiver became the main menu.
	event!(Menu, Event) becameMainMenu;

	/// This event is raised when the receiver was the main menu but is not longer.
	event!(Menu, Event) resignedAsMainMenu;
	
    private int widest;
    
    /// Creates a new instance of the receiver.
	this ()
	{
	    super();
	
		autoSize_ = true;
		visible = false;
		hasInvertedColors_ = true;
		hasBorder_ = true;
	}
	
	/// Gets the orientation of the menu.
	@property Orientation orientation ()
	{
	    if (Application.instance.mainMenu == this)
	        return Orientation.horizontal;
	    
	    return Orientation.vertical;
	}
	
	@property override Rect bounds (Rect bounds)
	{
	    bounds_ = bounds;
	    organize();
	    
	    return bounds_;
	}
	
	@property override bool visible (bool visible)
	{
	    hasInvertedColors = visible;
	    return super.visible = visible;
	}
	
	@property override bool hasBorder (bool hasBorder)
	{
	    super.hasBorder = hasBorder;
	    organize();
	    
	    return hasBorder_;
	}

	override Composite add (Control menuItem)
	{
	    children ~= menuItem;
	    
	    if (auto m = cast(MenuItem) menuItem)
	        m.parentMenu = this;
	    
	    organize();
	    return this;
	}

	override Composite remove (Control menuItem)
	{
	    super.remove(menuItem);
	    organize();
	    return this;
	}

	/// Organizes the menu items
	protected void organize ()
	{
	    Rect rect;
	    
	    if (autoSize)
	        bounds_.size.height = children.length;
	    
	    auto prevRect = bounds;
	    
	    foreach (i, item ; children)
	    {
	        rect = item.bounds;
	        rect.position = prevRect.position;
	        
	        if (i == 0)
	        {
	            if (orientation == Orientation.horizontal)
	                rect.position.x += margins.width;
	            
	            else if (hasBorder)
	                rect.position += 1;
	        }
	        
	        else
	        {
	            if (orientation == Orientation.vertical)
	                rect.position.y += prevRect.height;
	            
	            else
	                rect.position.x += prevRect.width;
	        }
	        
	        if (rect.width > widest)
	            widest = rect.width;
	        
	        prevRect = rect;
	        item.bounds = rect;
	    }
	    
	    if (autoSize)
	        organizeAutoSize(rect);
	}
	
	private void organizeAutoSize (ref Rect rect)
	{
        if (orientation == Orientation.vertical)
        {
            bounds_.size.width = widest;
            
            if (hasBorder)
                bounds_.size += 2;
        }
        
        foreach (item ; children)
        {
            auto m = item.margins;
            
            if (orientation == Orientation.vertical)
            {
                rect = item.bounds;
                rect.size.width = widest;
                
                item.autoSize = false;
                item.alignment = TextAlignment.left;
                m.width = 1;
                
                item.bounds = rect;
            }
            
            else
            {
                item.autoSize = false;
                item.alignment = TextAlignment.center;
                m.width = 2;
            }
            
            item.margins = m;
        }
	}

	/**
	 * Triggers a became main menu event and is the default handler for the event.
	 *
	 * Params:
     *     event = the event information
	 */
	void onBecameMainMenu (Event event)
	{
	    margins = Size(2, 0);
	    bounds = Rect(0, 0, Terminal.instance.bounds.size.width, 1);
	    hasBorder = false;
	    
	    becameMainMenu(this, event);
	}

	/**
	 * Triggers a resigned as main menu event and is the default handler for the event.
	 *
	 * Params:
     *     event = the event information
	 */
	void onResignedAsMainMenu (Event event)
	{
	    margins = Size(0, 0);
	    resignedAsMainMenu(this, event);
	}
}