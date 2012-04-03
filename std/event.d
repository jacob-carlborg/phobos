/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Aug 20, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/_responder.d)
 */
module std.event;

import std.algorithm;
import std.functional;
import std.traits;

/**
 * Events enable a class or object to notify other classes or objects when something of
 * interest occurs. The class that sends (or triggers) the event is called the $(I sender) and
 * the classes that receive (or handle) the event are called $(I receivers).
 * 
 * $(UL
 *  $(LI The sender determines when an event is triggered; the receivers determine what action
 *       is taken in response to the event)
 * 
 *  $(LI An event can have multiple receivers. A receiver can handle multiple events from
 *       multiple senders)
 * 
 *  $(LI Events that have no receivers are never triggered)
 * 
 *  $(LI Events are typically used to signal user actions such as button clicks or menu
 *       selections in graphical user interfaces)
 * 
 *  $(LI When an event has multiple receivers, the event handlers are invoked synchronously
 *       (in the order they were added to the event) when an event is raised)
 * )
 *
 * This is basically an implementation of the event concept that can be found in C#.
 * Because events don't have language support in D some things behave slightly different
 * compared to the C# implementation; e.g. it is possible to trigger an event out side of the
 * sender but you should never do this.
 *
 * Params:
 *     Sender = the type of the sender
 *     Event = the type of the event
 */
struct event (Sender, Event)
{
    /// An alias of the delegate signature.
    alias void delegate(const Sender, const Event) EventHandler;
    
    private EventHandler[] eventHandlers;
    
    /**
	 * Returns true if the event does not have any registered receivers.
	 *
	 * See_Also: $(LREF opCast)
	 */
	@property bool isEmpty ()
	{
	    return eventHandlers.length == 0;
	}

	/**
	 * Registers the given receiver/handler for the event.
	 *
     * Params:
     *     eventHandler = the handler to register for the event
	 *
	 * See_Also: $(LREF opBinary)
	 */
	void add (EventHandler eventHandler)
	{
	    // Using type inference for the delegate argument causes: Assertion failed: (!vthis->csym), function toObjFile, file glue.c, line 686.
	    if (!canFind!((EventHandler e) { return e == eventHandler; })(eventHandlers))
			eventHandlers ~= eventHandler;
	}

	/**
	 * Registers the given receiver/handler for the event.
	 *
     * Params:
     *     eventHandler = the handler to register for the event
	 *
	 * See_Also: $(LREF add)
	 */	
	void opBinary (string op) (EventHandler eventHandler) if (op == "~=")
	{
	    add(eventHandler);
	}

	/**
	 * Removes the given receiver/handler form list of receivers in the event.
	 *
     * Params:
     *     eventHandler = the handler to remove
	 *
	 * See_Also: $(LREF remove)
	 */
	void opBinary (string op) (EventHandler eventHandler) if (op == "-=")
	{
		remove(eventHandler);
	}

	/**
	 * Removes the given receiver/handler form list of receivers in the event
	 *
     * Params:
     *     eventHandler = the handler to remove
	 *
	 * See_Also: $(LREF opBinary)
	 */
	void remove (EventHandler eventHandler)
	{
	    // Using type inference for the delegate argument causes: Assertion failed: (!vthis->csym), function toObjFile, file glue.c, line 686.
		eventHandlers = .remove!((EventHandler e) { return e == eventHandler; })(eventHandlers);
	}

	/**
	 * Triggers the event.
	 *
     * Params:
     *     sender = the sender of the event
     *     event = the actual event
	 */
	void opCall (const Sender sender, const Event event) const
	{
        // foreach (e ; eventHandlers)
        //  e(sender, event);
	}

	/**
	 * Returns true if the event does not have any registered receivers.
	 *
	 * See_Also: $(LREF isEmpty)
	 */
	bool opCast (T : bool) () const
	{
		return isEmpty;
	}
}