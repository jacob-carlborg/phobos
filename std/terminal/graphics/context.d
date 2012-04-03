/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 22, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/terminal/geometry/_context.d)
 */
module std.terminal.graphics.context;

import std.stdio;
import std.internal.terminal.terminal : terminal;
import std.terminal.cursor;
import std.terminal.geometry.point;
import std.terminal.geometry.rect;
import std.terminal.graphics.color;

final class Context
{
    /// Gets/sets the foreground color.
    Color foreground;
    
    /// Gets/sets the background color.
    Color background; 
    
    /// Enables/disables bold text style.
    bool bold;
    
    /// Enables/disables inverted colors.
    bool invertColors;

	/// Enables/disables underline text style.
	bool underline;

    private static Context instance_;
	
	private this () {}
	
    /// Returns an instance of the receiver. 
    static Context instance ()
    {
        return instance_ = instance_ ? instance_ : new Context;
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