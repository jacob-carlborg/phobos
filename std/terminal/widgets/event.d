/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 6, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/terminal/widgets/_event.d)
 */
module std.terminal.widgets.event;

import std.terminal.geometry.point;

class Event
{
    /// The x and y coordinate of the cursor at the time the event occurred.
	Point point;

	/// A field for application use.
	void* data;

	/// Depending on the event, the character represented by the key that was typed.
	dchar character;

	/**
	 * Depending on the event, the state of the keyboard modifier keys at the time the event
	 * was generated.
	 */
	uint stateMask;

	/**
	 * Depending on the event, the key code of the key that was typed, as defined by the key
	 * code constants in enum Mambo.
	 */
	uint keyCode;

    /**
     * The type of event, as defined by the event type constants in
     * $(XREF terminal, widgets, event, EventType)
     */ 
	EventType type;
	
	///
	this () {}

	/// Creates a new instance with the properties of the given event.
	this (Event event)
	{
	    data = event.data;
	    character = event.character;
	    stateMask = event.stateMask;
	    keyCode = event.keyCode;
	    type = event.type;
	}

    /// Gets/sets the x coordinate of the event.
	@property int x () const
	{
	    return point.x;
	}
	
	/// Ditto
	@property int x (int x)
	{
	    return point.x = x;
	}

    /// Gets/sets the y coordinate of the event.
	@property int y () const
	{
	    return point.y;
	}
	
	/// Ditto
	@property int y (int y)
	{
	    return point.y = y;
	}

	/// Clones the receiver and returns a new instance.
	Event clone ()
	{
	    return new Event(this);
	}

	/// Tests if the state mask of the receiver contains the given state.
	bool stateMaskContains (uint state)
	{
	    return cast(bool) (stateMask & state);
	}
}

enum EventType
{
    /// The NULL event type (value is 0).
	none = 0,

	/// The key down event type (value is 1).
	keyDown = 1,

	/// The cursor move event type (value is 5).
	cursorMove = 5,

	/// The cursor enter event type (value is 6).
	cursorEnter = 6,

	/// The cursor exit event type (value is 7).
	cursorExit = 7,

	/// The draw event type (value is 8).
	draw = 8,

	/**
	 * The first key down event type. This is raised when the enter key is pressed
	 * (value is 9).
	 */
	firstKeyDown = 9,

	/**
	 * The second key down event type. This is raised when the space key is pressed
	 * (value is 10).
	 */
	secondKeyDown = 10
}