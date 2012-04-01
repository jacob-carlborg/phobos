/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 8, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/terminal/geometry/_point.d)
 */
module std.terminal.geometry.point;

struct Point
{
    /// The x coordinate of the point.
    int x;
    
    /// The y coordinate of the point.
    int y;
	 
    /**
     * Constructs a new Point with the given properties.
     * 
     * Params:
     *     x = the x coordinate of the point
     *     y = the y coordinate of the point
     */
    this (int x, int y)
    {
        this.x = x;
        this.y = y;
    }
}