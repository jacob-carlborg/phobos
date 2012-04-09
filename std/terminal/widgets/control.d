/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 6, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/terminal/widgets/_control.d)
 */
module std.terminal.widgets.control;

import std.conv;
import std.event;

import std.terminal.cursor;

import std.terminal.geometry.point;
import std.terminal.geometry.rect;
import std.terminal.geometry.size;

import std.terminal.graphics.color;
import std.terminal.graphics.graphicscontext;

import std.terminal.event;
import std.terminal.widgets.responder;
import std.terminal.widgets.terminal;

///
class Control : Responder
{
    protected
    {
        /// Storage for the backgroundColor property.
		Color backgroundColor_;

		/// Storage for the foregroundColor property.
		Color foregroundColor_;

		/// Storage for the hasBorder property.
		bool hasBorder_;

		/// Storage for the alignment property.
		TextAlignment alignment_;

		/// Storage for the margins property.
		Size margins_;

		/// Storage for the bounds property.
		Rect bounds_;

		/// Storage for the autoSize property.
		bool autoSize_;

		/// Storage for the stringValue property.
		string stringValue_;

		/// Storage for the isVisible property.
		bool visible_;

		/// Storage for the hasInvertedColors property.
		bool hasInvertedColors_;
    }

	private Responder lastResponder;
	
	/// The draw event. This event is raised when the receiver needs to be redrawn.
	event!(Control, Event) draw;
	
	/// Creates a new instance of the receiver.
	this ()
	{
	    super();

	    backgroundColor = Color.defaultColor;
	    foregroundColor = Color.defaultColor;
	    alignment = TextAlignment.center;
	    margins = Size(3, 0);
	    bounds = Rect(0, 0, 0, 0);
	    visible = true;
	    
	    draw ~= &this.onDraw;
	}

    /// Gets/sets the background color.
    @property Color backgroundColor () const
    {
        return backgroundColor_;
    }

    /// Ditto
    @property Color backgroundColor (Color backgroundColor)
    {
        return backgroundColor_ = backgroundColor;
    }

    /// Gets/sets the foreground color.
    @property Color foregroundColor () const
    {
        return foregroundColor_;
    }

    /// Ditto
    @property Color foregroundColor (Color foregroundColor)
    {
        return foregroundColor_ = foregroundColor;
    }

    /// Enables/disables border.
    @property bool hasBorder () const
    {
        return hasBorder_;
    }

    /// Ditto
    @property bool hasBorder (bool hasBorder)
    {
        return hasBorder_ = hasBorder;
    }

    /// Gets/sets text alignment.
    @property TextAlignment alignment () const
    {
        return alignment_;
    }

    /// Ditto
    @property TextAlignment alignment (TextAlignment alignment)
    {
        return alignment_ = alignment;
    }

    /// Gets/sets the margins of the receiver.
    @property Size margins () const
    {
        return margins_;
    }

    /// Ditto
    @property Size margins (Size margins)
    {
        return margins_ = margins;
    }

    /// Gets/sets the bounds of the receiver.
    @property Rect bounds () const
    {
        return bounds_;
    }

    /// Ditto
    @property Rect bounds (Rect bounds)
    {
        return bounds_ = bounds;
    }

    /// Enables/disables auto sizing of the receiver.s
    @property bool autoSize () const
    {
        return autoSize_;
    }

    /// Ditto
    @property bool autoSize (bool autoSize)
    {
        return autoSize_ = autoSize;
    }

    /// Gets/sets the string value of the receiver.
    @property string stringValue () const
    {
        return stringValue_;
    }

    /// Ditto
    @property string stringValue (string stringValue)
    {
        return stringValue_ = stringValue;
    }

    /// Gets/sets the integer value of the receiver.
    @property int intValue () const
    {
        return to!(int)(stringValue);
    }

    /// Ditto
    @property int intValue (int intValue)
    {
        stringValue = to!(string)(intValue);
        return intValue;
    }

    /// Enables/disables the visibility of the receiver.
    @property bool visible () const
    {
        return visible_;
    }

    /// Ditto
    @property bool visible (bool visible)
    {
        acceptsFirstResponder_ = visible;
        return visible_ = visible;
    }

    /// Enables/disables inverted colors on the receiver.
    @property bool hasInvertedColors () const
    {
        return hasInvertedColors_;
    }

    /// Ditto
    @property bool hasInvertedColors (bool hasInvertedColors)
    {
        return hasInvertedColors_ = hasInvertedColors;
    }
    
    protected @property override bool acceptsFirstResponder () const
	{
	    return acceptsFirstResponder_ && visible;
	}

	/**
	 * Tests if the receiver or any of its descendants contains the given point.
	 *
	 * Params:
     *     point = a point that is in the coordinate system of the receiver or any of its
     *            descendants.
	 */
	bool hitTest (const ref Point point) const
	{
	    return bounds.contains(point) && acceptsFirstResponder && enabled && visible;
	}

	/**
	 * Tests if the receiver or any of its descendants contains the given point.
	 *
	 * $(D_PARAM control) will contain the farthest descendant of the receiver in the control
	 * hierarchy (including itself) if this method returns true.
	 *
	 * Params:
     *     point = a point that is in the coordinate system of the receiver or any of its
     *             descendants.
     *     control = on return, contains the farthest descendant of the receiver in the
     *               control hierarchy
	 */
	bool hitTest (const ref Point point, out Control control)
	{
	    bool contains = hitTest(point);
	    
	    if (contains)
	        control = this;
	        
	    return contains;
	}

	/// Redraws the receiver, sends a draw event to the receiver.
	void redraw () const
	{
	    auto event = new Event;
	    event.type = EventType.draw;
	    
	    draw(this, event);
	}

	/**
	 * Default handler for the drawing event.
	 *
	 * Params:
     *     event = the event information
	 */
	protected void onDraw (const Control control, const Event event) const
    {
        auto gc = GraphicsContext.instance;
        auto bounds = this.bounds;
        
        if (visible)
        {
            gc.invertColors = hasInvertedColors;
            gc.background = backgroundColor;
            gc.foreground = foregroundColor;
            
            gc.fillRectangle(bounds);
            
            if (hasBorder)
                gc.drawRectangle(bounds);
        }
        
        else
        {
            auto term = Terminal.instance;
            gc.background = term.backgroundColor;
            gc.foreground = term.foregroundColor;
            gc.fillRectangle(bounds);
            
            auto controls = term.getIntersectingControls(bounds);
            
            foreach_reverse (control ; controls)
                if (control !is this && control.visible)
                    control.redraw();
        }
    }

	/**
	 * Sends a cursor moved event and is the default handler for the event.
	 * 
	 * Params:
     *     event = the event information
	 */
	override void onCursorMoved (const Event event)
	{
	    if (!enabled)
	        return;
	    
	    auto cursor = Cursor.instance;

	    switch (event.keyCode)
	    {
	        case Key.arrowDown: cursor.moveDown(); break;
	        case Key.arrowLeft: cursor.moveLeft(); break;
	        case Key.arrowRight: cursor.moveRight(); break;
	        case Key.arrowUp: cursor.moveUp(); break;
	    }
	    
	    cursorMoved(this, event);
	    auto cursorPosition = cursor.position;
	    
	    Control responder;
	    
	    if (hitTest(cursorPosition, responder) && responder)
	    {
	        auto term = Terminal.instance;

	        if (!lastResponder)
	            lastResponder = term.firstResponder;
	        
	        // if the responder has changed since last time, i.e. the cursor has left the
	        // responder.
	        if (lastResponder !is responder)
	        {
	            auto e = event.clone();
	            e.type = EventType.cursorExit;
	            term.sendEvent(e, lastResponder);
	            
	            e = event.clone();
	            e.point = cursorPosition;
	            e.type = EventType.cursorEnter;
	            term.sendEvent(e, lastResponder);
	        }
	        
	        lastResponder = responder;
	    }
	}
}

///
enum TextAlignment
{
    ///
    left,
    
    ///
    center,
    
    ///
    right
}