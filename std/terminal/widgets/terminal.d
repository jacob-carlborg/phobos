/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 21, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/terminal/widgets/_terminal.d)
 */
module std.terminal.widgets.terminal;

import std.internal.terminal.terminal : terminal;

import std.terminal.graphics.color;
import std.terminal.geometry.rect;
import std.terminal.widgets.control;
import std.terminal.widgets.responder;
import std.terminal.widgets.composite;
import std.terminal.event;
import std.terminal.cursor;
import std.terminal.graphics.graphicscontext;
import std.terminal.application;

class Terminal : Composite
{
    private static Terminal instance_;
    
    @property static Terminal instance ()
    {
        return instance_ = instance_ ?  instance_ : new Terminal;
    }
    
	/// The responder that’s made first responder the first time the terminal is displayed.
	Responder initialFirstResponder;

    /// Storage for the cursor property.
	protected Cursor cursor_;
	protected Responder firstResponder_;
	
	this ()
	{
	    initialFirstResponder = this;
		firstResponder_ = initialFirstResponder;
		acceptsFirstResponder_ = true;
		cursor_ = Cursor.instance;
		acceptsCursorMovedEvents = true;
	}

	/// Gets the first responder.
	@property Responder firstResponder ()
	{
	    return firstResponder_;
	}

	/// Gets the cursor.
	@property Cursor cursor ()
	{
	    return cursor;
	}

	/// Gets the bounds of the receiver.
	@property override Rect bounds ()
	{
	    return Rect(0, 0, terminal.width, terminal.height);
	}

	/**
	 * Attempts to make the given responder the first responder for the terminal.
	 *
	 * If responder isn’t already the first responder, this method first class the
	 * resignFirstResponder method to the object that is the first responder.
	 * If that object refuses to resign, it remains the first responder, and
	 * this method immediately returns $(D_CODE false). If the current first
	 * responder resigns, this method calls the becomeFirstResponder method on
	 * responder. If responder does not accept first responder status, the Terminal
	 * object becomes first responder; in this case, the method returns
	 * $(D_CODE true) even if responder refuses first responder status.
	 *
	 * If responder is $(D_CODE null), this method still calls resignFirstResponder
	 * on the current first responder. If the current first responder refuses to
	 * resign, it remains the first responder and this method immediately returns
	 * $(D_CODE false).If the current first responder returns $(D_CODE true)
	 * from resignFirstResponder, the terminal is made its own first responder and
	 * this method returns $(D_CODE true).
	 *
	 * The Mambo framework uses this method to alter the first responder
	 * in response to cursor-moved events; you can also use it to explicitly set the
	 * first responder from within your program. The responder object is typically a
	 * Control object in the terminal’s hierarchy. If this method is called
	 * explicitly, first call acceptsFirstResponder on responder, and do not call
	 * makeFirstResponder if acceptsFirstResponder returns $(D_CODE false).
	 *
	 * Use initialFirstResponder to the set the first responder to be used
	 * when the terminal is displayed for the first time.
	 *
	 * Params:
     *     responder = the responder to set as the terminal's first responder
	 *
	 * Returns: $(D_CODE true) when the operation is successful; otherwise, $(D_CODE false).
	 */
	bool makeFirstResponder (Responder responder)
	{
	    if (responder is firstResponder)
	        return true;
	    
	    if (!firstResponder_.resignFirstResponder())
	        return false;
	    
	    if (!responder.becomeFirstResponder())
	    {
	        firstResponder_ = this;
	        return true;
	    }
	    
	    firstResponder_ = responder;
	    return true;
	}

	/**
	 * This action method dispatches cursor and keyboard events sent to the terminal by
	 * the Application object.
	 *
	 * Never invoke this method directly.
	 *
	 * Params:
     *     event = the cursor or keyboard event to process
	 */
	void sendEvent (Event event)
	{
	    if (event.type == EventType.cursorMove)
	    {
	        Control control;
	        
	        if (hitTest(event.point, control) && control)
	            sendEvent(event, control);
	    }
	    
	    else
	        sendEvent(event, firstResponder);
	}

	/**
	 * This action method dispatches cursor and keyboard events sent to the terminal by
	 * the Application object to the given responder.
	 *
	 * Never invoke this method directly.
	 *
	 * Params:
     *     event = the cursor or keyboard event to process
     *     responder = the responder to send the event to
	 */
	void sendEvent (Event event, Responder responder)
	{
	    switch (event.type)
	    {
	        case EventType.cursorMove:
	        {
	            if (responder.acceptsCursorMovedEvents &&
	                responder.acceptsFirstResponder &&
	                makeFirstResponder(responder))
	                    responder.onCursorMoved(event);
	            
	            else if (responder.enabled && firstResponder.acceptsCursorMovedEvents)
	                firstResponder.onCursorMoved(event);
	            
	            else
	                // let the terminal handle the cursor moved events even if it is not the
	                // first responder
	                onCursorMoved(event);
	        }
	        break;
	        
	        case EventType.cursorEnter:
	            if (responder.acceptsFirstResponder && makeFirstResponder(responder))
	                responder.onCursorEntered(event);
	        break;
	        
	        case EventType.cursorExit:
	            if (responder.acceptsFirstResponder && makeFirstResponder(responder))
	                responder.onCursorExited(event);
	        break;
	    
	        case EventType.keyDown:
	            if (event.keyCode == Key.enter)
	                responder.onFirstKeyDown(event);
	            
	            else
	                responder.onKeyDown(event);
	        break;
	        
	        default:
	    }
	}

	protected override void onDraw (Control control, Event event) const
	{
	    if (!visible)
	    {
	        super.onDraw(control, event);
	        return;
	    }
	    
	    GraphicsContext.instance.clearScreen();
	    
	    if (Application.instance.mainMenu)
	        Application.instance.mainMenu.redraw();
	        
	    
	    foreach (child ; children)
	        child.redraw();
	}
}

enum Key
{
    /**
	 * Keyboard event mask indicating that the CTRL key
	 * was pushed on the keyboard when the event was generated
	 * (value is 1&lt;&lt;18).
	 */
	ctrl = 1 << 18,

	/**
	 * Keyboard event mask indicating that the CTRL key
	 * was pushed on the keyboard when the event was generated. This
	 * is a synonym for $(D_CODE ctrl) (value is 1&lt;&lt;18).
	 */
	control = ctrl,

	/**
	 * Accelerator constant used to differentiate a key code from a
	 * unicode character.
	 *
	 * If this bit is set, then the key stroke
	 * portion of an accelerator represents a key code.  If this bit
	 * is not set, then the key stroke portion of an accelerator is
	 * a unicode character.
	 *
	 * (value is (1&lt;&lt;24))
	 */
	keycodeBit = (1 << 24),

	/**
	 * Keyboard event constant representing the UP ARROW key
	 * (value is (1&lt;&lt;24)+1).
	 */
	arrowUp = keycodeBit + 1,

	/**
	 * Keyboard event constant representing the DOWN ARROW key
	 * (value is (1&lt;&lt;24)+2).
	 */
	arrowDown = keycodeBit + 2,

	/**
	 * Keyboard event constant representing the LEFT ARROW key
	 * (value is (1&lt;&lt;24)+3).
	 */
	arrowLeft = keycodeBit + 3,

	/**
	 * Keyboard event constant representing the RIGHT ARROW key
	 * (value is (1&lt;&lt;24)+4).
	 */
	arrowRight = keycodeBit + 4,

	/**
	 * Keyboard event constant representing the PAGE UP key
	 * (value is (1&lt;&lt;24)+5).
	 */
	pageUp = keycodeBit + 5,

	/**
	 * Keyboard event constant representing the PAGE DOWN key
	 * (value is (1&lt;&lt;24)+6).
	 */
	pageDown = keycodeBit + 6,

	/**
	 * Keyboard event constant representing the HOME key
	 * (value is (1&lt;&lt;24)+7).
	 */
	home = keycodeBit + 7,


	/**
	 * Keyboard event constant representing the END key
	 * (value is (1&lt;&lt;24)+8).
	 */
	end = keycodeBit + 8,

	/**
	 * Keyboard event constant representing the INSERT key
	 * (value is (1&lt;&lt;24)+9).
	 */
	insert = keycodeBit + 9,

    /**
     * Keyboard event constant representing the F1 key
     * (value is (1&lt;&lt;24)+10).
     */
    f1 = keycodeBit + 10,

    /**
     * Keyboard event constant representing the F2 key
     * (value is (1&lt;&lt;24)+11).
     */
    f2 = keycodeBit + 11,

    /**
     * Keyboard event constant representing the F3 key
     * (value is (1&lt;&lt;24)+12).
     */
    f3 = keycodeBit + 12,

    /**
     * Keyboard event constant representing the F4 key
     * (value is (1&lt;&lt;24)+13).
     */
    f4 = keycodeBit + 13,

    /**
     * Keyboard event constant representing the F5 key
     * (value is (1&lt;&lt;24)+14).
     */
    f5 = keycodeBit + 14,

    /**
     * Keyboard event constant representing the F6 key
     * (value is (1&lt;&lt;24)+15).
     */
    f6 = keycodeBit + 15,

    /**
     * Keyboard event constant representing the F7 key
     * (value is (1&lt;&lt;24)+16).
     */
    f7 = keycodeBit + 16,

    /**
     * Keyboard event constant representing the F8 key
     * (value is (1&lt;&lt;24)+17).
     */
    f8 = keycodeBit + 17,

    /**
     * Keyboard event constant representing the F9 key
     * (value is (1&lt;&lt;24)+18).
     */
    f9 = keycodeBit + 18,

    /**
     * Keyboard event constant representing the F10 key
     * (value is (1&lt,&lt,24)+19).
     */
    f10 = keycodeBit + 19,

    /**
     * Keyboard event constant representing the F11 key
     * (value is (1&lt,&lt,24)+20).
     */
    f11 = keycodeBit + 20,

    /**
     * Keyboard event constant representing the F12 key
     * (value is (1&lt,&lt,24)+21).
     */
    f12 = keycodeBit + 21,

    /**
     * Keyboard event constant representing the F13 key
     * (value is (1&lt,&lt,24)+22).
     */
    f13 = keycodeBit + 22,

    /**
     * Keyboard event constant representing the F14 key
     * (value is (1&lt,&lt,24)+23).
     */
    f14 = keycodeBit + 23,

    /**
     * Keyboard event constant representing the F15 key
     * (value is (1&lt,&lt,24)+24).
     */
    f15 = keycodeBit + 24,

    /**
     * Keyboard event constant representing the F16 key
     * (value is (1&lt,&lt,24)+25).
     */
    f16 = keycodeBit + 25,

    /**
     * Keyboard event constant representing the F17 key
     * (value is (1&lt,&lt,24)+26).
     */
    f17 = keycodeBit + 26,

    /**
     * Keyboard event constant representing the F18 key
     * (value is (1&lt,&lt,24)+27).
     */
    f18 = keycodeBit + 27,

    /**
     * Keyboard event constant representing the F19 key
     * (value is (1&lt,&lt,24)+28).
     */
    f19 = keycodeBit + 28,

    /**
     * Keyboard event constant representing the F20 key
     * (value is (1&lt,&lt,24)+29).
     */
    f20 = keycodeBit + 29,

	/**
	 * Keyboard event constant representing the DEL key
	 * (value is (1&lt,&lt,24)+30).
	 */
	del = keycodeBit + 30,

	/**
	 * Keyboard event constant representing the Backspace key
	 * (value is (1&lt,&lt,24)+31).
	 */
	backspace = keycodeBit + 31,

	/**
	 * Keyboard event constant representing the numeric key
	 * pad multiply key (value is (1&lt,&lt,24)+42).
	 */
	keypadMultiply = keycodeBit + 42,

	/**
	 * Keyboard event constant representing the numeric key
	 * pad add key (value is (1&lt,&lt,24)+43).
	 */
	keypadAdd = keycodeBit + 43,

	/**
	 * Keyboard event constant representing the numeric key
	 * pad subtract key (value is (1&lt,&lt,24)+45).
	 */
	keypadSubtract = keycodeBit + 45,

	/**
	 * Keyboard event constant representing the numeric key
	 * pad decimal key (value is (1&lt,&lt,24)+46).
	 */
	keypadDecimal = keycodeBit + 46,

	/**
	 * Keyboard event constant representing the numeric key
	 * pad divide key (value is (1&lt,&lt,24)+47).
	 */
	keypadDivide = keycodeBit + 47,

    /**
     * Keyboard event constant representing the numeric key
     * pad zero key (value is (1&lt,&lt,24)+48).
     */
    keypad0 = keycodeBit + 48,

    /**
     * Keyboard event constant representing the numeric key
     * pad one key (value is (1&lt,&lt,24)+49).
     */
    keypad1 = keycodeBit + 49,

    /**
     * Keyboard event constant representing the numeric key
     * pad two key (value is (1&lt,&lt,24)+50).
     */
    keypad2 = keycodeBit + 50,

    /**
     * Keyboard event constant representing the numeric key
     * pad three key (value is (1&lt,&lt,24)+51).
     */
    keypad3 = keycodeBit + 51,

    /**
     * Keyboard event constant representing the numeric key
     * pad four key (value is (1&lt,&lt,24)+52).
     */
    keypad4 = keycodeBit + 52,

    /**
     * Keyboard event constant representing the numeric key
     * pad five key (value is (1&lt,&lt,24)+53).
     */
    keypad5 = keycodeBit + 53,

    /**
     * Keyboard event constant representing the numeric key
     * pad six key (value is (1&lt,&lt,24)+54).
     */
    keypad6 = keycodeBit + 54,

    /**
     * Keyboard event constant representing the numeric key
     * pad seven key (value is (1&lt,&lt,24)+55).
     */
    keypad7 = keycodeBit + 55,

    /**
     * Keyboard event constant representing the numeric key
     * pad eight key (value is (1&lt,&lt,24)+56).
     */
    keypad8 = keycodeBit + 56,

    /**
     * Keyboard event constant representing the numeric key
     * pad nine key (value is (1&lt,&lt,24)+57).
     */
    keypad9 = keycodeBit + 57,

	/**
	 * Keyboard event constant representing the numeric key
	 * pad equal key (value is (1&lt,&lt,24)+61).
	 */
	keypadEqual = keycodeBit + 61,

	/**
	 * Keyboard event constant representing the numeric key
	 * pad enter key (value is (1&lt,&lt,24)+80).
	 */
	keypadCr = keycodeBit + 80,

	/**
	 * Keyboard event constant representing the numeric key
	 * pad enter key (value is keypadCr).
	 */
	enter = keypadCr,

	/**
	 * Keyboard event constant representing the numeric key
	 * pad enter key (value is keypadCr.
	 */
	return_ = keypadCr
	
}
