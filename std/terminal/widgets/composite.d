/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 8, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/terminal/widgets/_composite.d)
 */
module std.terminal.widgets.composite;

import std.algorithm;

import std.terminal.widgets.control;
import std.terminal.geometry.rect;
import std.terminal.geometry.point;
import std.terminal.event;

class Composite : Control
{
    alias Control.visible visible;
    alias Control.bounds bounds;
    
	/// The children controls this composite contains
	protected Control[] children;
	
	@property override Rect bounds (Rect bounds)
    {
        foreach (child ; children)
        {
            auto rect = child.bounds;
            rect.position += bounds.position;
            child.bounds = rect;
        }
        
        return bounds_ = bounds;
    }
    
    @property override bool visible (bool visible)
    {
        super.visible = visible;
        
        foreach (child ; children)
            child.visible = visible;
        
        return visible_;
    }
	
	/**
	 * Adds the given control to the receiver
	 *
	 * Params:
     *     control = the control to add to the receiver
     * 
     * Returns: the receiver
	 */
	Composite add (Control control)
	{
        children ~= control;
        
        auto rect = control.bounds;
        rect.position += bounds.position;
        control.bounds = rect;
        
        return this;
	}

	/**
	 * Adds the given control to the receiver
	 *
	 * Params:
     *     control = the control to add to the receiver
	 *
	 * Returns: the receiver
	 */
	Composite opOpAssign (string op) (Control control) if (op == "~")
	{
	    return add(control);
	}

	/**
	 * Removes the given control from the receiver
	 *
	 * Params:
     *     control = the control to remove from the receiver
     * 
     * Returns: the receiver
	 */
	Composite remove (Control control)
	{
	    .remove!((Control e) { return e is control; })(children);
	    return this;
	}

	/**
	 * Removes the given control from the receiver
	 *
	 * Params:
     *     control = the control to remove from the receiver
     * 
     * Returns: the receiver
	 */
	Composite opOpAssign (string op) (Control control) if (op == "-")
	{
	    return this.remove(control);
	}

	override bool hitTest (const ref Point point) const
	{
	    bool contains = bounds.contains(point) && acceptsFirstResponder && enabled;
	    
	    if (contains)
	    {
	        foreach (child ; children)
	            if (child.hitTest(point))
	                break;
	    }
	    
	    return contains;
	}
	
	override bool hitTest (const ref Point point, out Control control)
	{
	    bool contains = bounds.contains(point) && acceptsFirstResponder && enabled;

	    if (contains)
	    {
	        foreach (child ; children)
	            if (child.hitTest(point, control))
	                break;

	        if (!control)
	            control = this;
	    }

	    return contains;
	}

	/**
	 * Returns a list of all the controls that the receiver contains and intersect with the
	 * given rectangle.
	 *
	 * Params:
     *     rect = the rectangle to test for intersection
	 *
	 * Returns: a list of all the controls that intersect with the given rectangle
	 */
	Control[] getIntersectingControls (const ref Rect rect)
	{
	    Control[] controls;
	    controls.reserve(children.length);
	    
	    foreach (control ; children)
	    {
	        auto bounds = control.bounds;
	        
	        if (rect.intersects(bounds) && !canFind!((Control e) { return e is control;})(controls))
	            controls ~= control;
	    }
	            
	    return controls;
	}

	override bool performKeyEquivalent (const Event event)
	{
	    foreach (child ; children)
	        if (child.performKeyEquivalent(event))
	            return true;
	    
	    return false;
	}

	protected override void onDraw (const Control control, const Event event) const
	{
	    super.onDraw(control, event);
	    
	    if (visible)
	    {
	        foreach (child ; children)
	            child.redraw();
	    }
	}
}