/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 8, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/terminal/geometry/_size.d)
 */
module std.terminal.geometry.size;

struct Size
{
    /// The width of the size.
    int width;
    
    /// The height of the size.
    int height;
	 
    /**
     * Constructs a new Size with the given properties.
     * 
     * Params:
     *     width = the width of the size
     *     height = the height of the size
     */
    this (int width, int height)
    {
        this.width = width;
        this.height = height;
    }
    
    /**
     * Overloads the += and -= operators. Increments or decrements the "width" and "height"
     * fields with the given value.
     * 
     * Returns: the receiver
     */
    Size opOpAssign (string op) (int value) if (op == "+" || op == "-")
    {
        mixin("width " ~ op ~ "= value;");
        mixin("height " ~ op ~ "= value;");
        
        return this;
    }
}