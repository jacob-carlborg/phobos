/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 8, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/terminal/geometry/_rect.d)
 */
module std.terminal.geometry.rect;

import std.algorithm : min, max;
import std.terminal.geometry.point;
import std.terminal.geometry.size;

struct Rect
{
    /// The position of the rectangle.
    Point position;

    /// The size of the rectangle.
    Size size;
    
    /**
     * Constructs a new Rect with the given properties.
     *
     * Params:
     *     x = the x coordinate of the rectangle
     *     y = the y coordinate of the rectangle
     *     width = the width of the rectangle
     *     height = the height of the rectangle
     */
    this (int x, int y, int width, int height)
    {
        position.x = x;
        position.y = y;
        
        size.width = width;
        size.height = height;
    }
    
    /// The x coordinate of the rectangle, shortcut for position.x.
    @property int x () const
    {
        return position.x;
    }
    
    /// Ditto
    @property int x (int x)
    {
        return position.x = x;
    }
    
    /// The y coordinate of the rectangle, shortcut for position.y.
    @property int y () const
    {
        return position.y;
    }
    
    /// Ditto
    @property int y (int y)
    {
        return position.y = y;
    }

    /// The width of the rectangle, shortcut for size.width.
    @property int width () const
    {
        return size.width;
    }
    
    /// Ditto
    @property int width (int width)
    {
        return size.width = width;
    }
 
    /// The height of the rectangle, shortcut for size.height.
    @property int height () const
    {
        return size.width;
    }
    
    /// Ditto
    @property int height (int height)
    {
        return size.height = height;
    }
    
    /// Returns true if receiver contains the given point.
    bool contains (const ref Point point) const
    {
        return point.x >= position.x &&
			   point.y >= position.y &&
			   point.x < position.x + size.width &&
			   point.y < position.y + size.height;
    }
    
    /// Tests for intersection of the receiver and the given rectangle.
	bool intersects (const ref Rect rect) const
	{
	    return !(rect.x > x + width ||
				 rect.x + rect.width < x ||
				 rect.y > y + height ||
				 rect.y + rect.height < y);
	}

	/**
	 * Tests for intersection of the receiver and the given rectangle.
	 * 
     * Params:
     *     rect = the rectangle to test for intersection
     *     intersection = on return, contains the rectangle that was the result of the
     *                    intersection
	 */
	bool intersects (const ref Rect rect, out Rect intersection) const
	{
	    bool intersects = intersects(rect);
	    
	    if (intersects)
		{
			int newX1 = max(this.x, rect.x);
			int newY1 = max(y, rect.y);
			int newX2 = min(width + x, rect.width + rect.x);
			int newY2 = min(height + y, rect.height + rect.y);
			int newWidth = newX2 - newX1;
			int newHeight = newY2 - newY1;

			intersection = Rect(newX1, newY1, newWidth, newHeight);
		}

		return intersects;
	}

	/**
	 * Centers the position of the receiver in the given rectangle.
	 *
	 * This is useful when you want to center an object inside another. For example, center a
	 * window on the screen, in this case the receiver will be the window and the given
	 * rectangle will be the screen.
	 * 
	 * Params:
	 *     rect = the rectangle to center in. The size of the given rectangle needs to be
	 *            greater than the size of the receiver.
	 */
	void centerPosition (const ref Rect rect)
	in
	{
	    assert(rect.width > 0);
	    assert(rect.height > 0);
	    assert(width > 0);
	    assert(height > 0);
	}
	body
	{
	    auto p = Rect.centerPosition(rect, this);
	    x = p.x;
	    y = p.y;
	}

	/**
	 * Centers the position of the first given rectangle in the second.
	 *
	 * This is useful when you want to center an object inside another. For example, center a
	 * window on the screen, in this case the receiver will be the window and the given
	 * rectangle will be the screen.
	 *
	 * Params:
	 *     rect1 = the rectangle to be centered
	 *     rect2 = the rectangle to center in
	 *
	 * Returns: the new position of the rectangle
	 */
	static Point centerPosition (const ref Rect rect1, const ref Rect rect2)
	in
	{
	    assert(rect1.width > 0);
	    assert(rect1.height > 0);
	    assert(rect2.width > 0);
	    assert(rect2.height > 0);
	}
	body
	{
	    return Point((rect2.width / 2 - rect1.width / 2) + rect2.x, (rect2.height / 2 - rect1.height / 2) + rect2.y);
	}
}