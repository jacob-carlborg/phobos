/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 6, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/terminal/widgets/_responder.d)
 */
module std.terminal.widgets.responder;

import std.event;
import std.terminal.event;

class Responder
{
    /// Enables/disables if the receiver accepts cursor moved events.
    bool acceptsCursorMovedEvents;

	/// This event is triggered when the cursor is moved over the receiver.
	event!(Responder, Event) cursorMoved;

	/// This event is triggered when the cursor has entered the receiver.
	event!(Responder, Event) cursorEntered;

	/// This event is triggered when the cursor has exited the receiver.
	event!(Responder, Event) cursorExited;

	/**
	 * This event is triggered when a key is pressed down over the receiver and when the key
	 * is not the first key or any of the arrow keys (they will trigger their own events).
	 */
	event!(Responder, Event) keyDown;

	/**
	 * This event is triggered when the first key is pressed down over the receiver. This is
	 * the enter/return key.
	 */
	event!(Responder, Event) firstKeyDown;
    
    /// Storage for the acceptsFirstResponder property.
    protected bool acceptsFirstResponder_;

    /// Storage for the enabled property.
    protected bool enabled_;
    
    /// Creates a new instance of the receiver.
    this ()
    {
       enabled = true; 
    }
    
    /**
	 * If true, the receiver accepts first responder status. Override this method in
	 * subclasses to return true if the receiver accepts first responder status.
	 *
	 * As first responder, the receiver is the first object in the responder chain to be sent
	 * key events and action messages. The Responder implementation returns false, indicating
	 * that by default a responder object does not agree to become first responder.
	 */
	@property bool acceptsFirstResponder () const
	{
	    return acceptsFirstResponder_;
	}
	
	/// Enables/disables whether the receiver reacts to cursor and key events.
	@property bool enabled () const
	{
	    return enabled_;
	}
	
	/// Ditto
	@property bool enabled (bool enabled)
	{
	    return enabled_ = enabled;
	}
	
	/**
	 * Notifies the receiver that it’s about to become first responder in its Terminal.
	 *
	 * The default implementation returns $(D_CODE true), accepting first responder status.
	 * Subclasses can override this method to update state or perform some action such as
	 * highlighting the selection, or to return $(D_CODE false), refusing first responder
	 * status.
	 *
	 * Use the $(XREF terminal, Terminal, makeFirstResponder) method, not this method, to make
	 * an object the first responder. Never invoke this method directly.
	 */
	bool becomeFirstResponder ()
	{
	    return true;
	}

	/**
	 * Notifies the receiver that it’s been asked to relinquish its status as first responder
	 * in its terminal.
	 *
	 * The default implementation returns true, resigning first responder status. Subclasses
	 * can override this method to update state or perform some action such as unhighlighting
	 * the selection, or to return false, refusing to relinquish first responder status.
	 *
	 * Use the Terminal makeFirstResponder method, not this method, to make an object the
	 * first responder. Never invoke this method directly.
	 *
	 * Returns: true if the receiver resigned as first responder, otherwise false
	 * See_Also: $(XREF terminal, Terminal, makeFirstResponder)
	 */
	bool resignFirstResponder ()
	{
	    return true;
	}

	/**
	 * Overridden by subclasses to handle a key equivalent.
	 *
	 * If the character code or codes in event match the receiver’s key equivalent,
	 * the receiver should respond to the event and return true. The default implementation
	 * does nothing and returns false.
	 *
	 * Params:
     *     event = an event object that represents the key equivalent pressed
	 */
	bool performKeyEquivalent (const Event event)
	{
	    return false;
	}

	/**
	 * Triggers a cursor moved event and is the default handler for the event.
	 *
	 * Params:
     *     event = the event information
	 */
	void onCursorMoved (const Event event) const
	{
	    if (enabled && acceptsCursorMovedEvents)
	        cursorMoved(this, event);
	}

	/**
	 * Triggers a cursor entered event and is the default handler for the event.
	 *
	 * Params:
     *     event = the event information
	 */
	void onCursorEntered (const Event event)
	{
	    if (enabled)
	        cursorEntered(this, event);
	}

	/**
	 * Triggers a cursor moved exited and is the default handler for the event.
	 *
	 * Params:
     *     event = the event information
	 */
	void onCursorExited (const Event event)
	{
	    if (enabled)
	        cursorExited(this, event);
	}

	/**
	 * Triggers a key down event and is the default handler for the event.
	 *
	 * Params:
     *     event = the event information
	 */
	void onKeyDown (const Event event)
	{
	    if (enabled)
	        keyDown(this, event);
	}

	/**
	 * Triggers a fist key down event and is the default handler for the event.
	 *
	 * Params:
     *     event = the event information
	 */
	void onFirstKeyDown (const Event event)
	{
	    if (enabled)
	        firstKeyDown(this, event);
	}
}