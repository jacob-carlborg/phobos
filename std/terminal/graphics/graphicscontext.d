/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 22, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/terminal/geometry/_graphicscontext.d)
 */
module std.terminal.graphics.graphicscontext;

import std.stdio;
import std.internal.terminal.terminal : terminal;
import std.terminal.cursor;
import std.terminal.geometry.point;
import std.terminal.geometry.rect;
import std.terminal.graphics.color;

final class GraphicsContext
{
    private
    {
        static GraphicsContext instance_;
        
        Color foreground_;
        Color background_;
        
        bool bold_;
        bool invertColors_;
        bool underline_;
    }
	
	private this () {}
	
    /// Returns an instance of the receiver.
    @property static GraphicsContext instance ()
    {
        return instance_ = instance_ ? instance_ : new GraphicsContext;
    }

	/// Gets/sets the foreground color.
    @property Color foreground ()
    {
        return foreground_;
    }
    
    /// Ditto
    @property Color foreground (Color color)
    {
        terminal.foregroundColor(color);
        return foreground_ = color;
    }
    
    /// Gets/sets the background color.
    @property Color background ()
    {
        return background_;
    }
    
    /// Ditto
    @property Color background (Color color)
    {
        terminal.backgroundColor(color);
        return background_ = color;
    }
    
    /// Enables/disables bold text style.
    @property bool bold ()
    {
        return bold_;
    }
    
    /// Ditto
    @property bool bold (bool bold)
    {
        if (bold)
            terminal.bold();
        
        else
        {
            terminal.normal();
            
            if (invertColors)
                terminal.reverse();
            
            if (underline)
                terminal.underline();
        }
        
        return bold_ = bold;
    }
    
    /// Enables/disables inverted colors.
    @property bool invertColors ()
    {
        return invertColors_;
    }
    
    /// Ditto
    @property bool invertColors (bool invertColors)
    {
        if (invertColors)
            terminal.reverse();
        
        else
        {
            terminal.normal();
            
            if (bold)
                terminal.bold();
                
            if (underline)
                terminal.underline();

        }
        
        return invertColors_ = invertColors;
    }

	/// Enables/disables underline text style.
	@property bool underline ()
	{
	    return underline_;
	}
	
	/// Ditto
	@property bool underline (bool underline)
	{
	    if (underline)
	        terminal.underline();
	        
	    else
	    {
	        terminal.normal();
	        
	        if (bold)
	            terminal.bold();
	        
	        if (invertColors)
	            terminal.reverse();
	    }
	    
	    return underline_ = underline;
	}
    
    /// Clears the screen.
	void clearScreen () const
	{
	    terminal.clearScreen();
	}

	/**
	 * Draws an outline of a rectangle on the screen.
	 * 
	 * Params:
     *     rect = the bounds of the rectangle to draw
	 */
	void drawRectangle (const ref Rect rect) const
	{
	    terminal.box(rect);
	}

	/**
	 * Draws a line on the screen.
	 * 
	 * Params:
     *     start = the start position of the line
     *     end = the end position of the line
	 */
	void drawLine (const ref Point start, const ref Point end) const
	{
	    if (start.x == end.x)
	        terminal.verticalLine(start, end.y);
	        
	    else if (start.y == end.y)
	        terminal.horizontalLine(start, end.x);
	}

	/**
	 * Draws a table on the screen.
	 * 
	 * Params:
     *     start = the start position of the table
     *     rows = the number of screen rows for each table row
     *     columns = the number of screen columns for each table column
	 */
	void drawTable (const ref Point start, const int[] rows, const int[] columns) const
	{
	    terminal.table(start, rows, columns);
	}

	/**
	 * Draws a filled rectangle on the screen.
	 * 
	 * Params:
     *     rect = the bounds of the rectangle to draw
	 */
	void fillRectangle (const ref Rect rect) const
	{
	    auto prevPos = Cursor.instance.move(rect.position);
	    
	    foreach (i ; 0 .. rect.height)
	    {
	        foreach (_ ; 0 .. rect.width)
	            write(" ");
	            
	        Cursor.instance.moveDown();
	        Cursor.instance.moveLeft(rect.width);
	    }
	    
	    Cursor.instance.move(prevPos);
	}
}