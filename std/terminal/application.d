/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 6, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/terminal/_application.d)
 */
module std.terminal.application;

import std.event;
import std.uni;

import Internal = std.internal.terminal.terminal;

import std.terminal.widgets.control;
import std.terminal.event;
import std.terminal.widgets.responder;
import std.terminal.widgets.terminal;


class Menu : Control
{
    override void redraw () {}
    void onResignedAsMainMenu (Event) {}
    void onBecameMainMenu (Event) {}
}

class Application
{
    protected
    {
        static Application instance_;
        
        Terminal mainTerminal_;
    	bool isRunning_;
    	Menu mainMenu_;
    	bool delegate (Application, Responder) shouldTerminate_;
    }

    private	Event[] internalEventQueue;
    private alias Internal.KeyCode KeyCode;

	/**
	 * This event is triggered when the terminate method has been called.
	 *
	 * See_Also:
	 *  $(UL
	 *      $(LI $(LREF shouldTerminate))
	 *      $(LI $(LREF terminate))
	 *  )
	 */
	event!(Application, Responder) willTerminate;
	
	this ()
	{
	    mainTerminal_ = Terminal.instance;
	}
	
	@property static Application instance ()
	{
	    return instance_ = instance_ ? instance_ : new Application;
	}

    /// Is true if the application's event loop has been started and is still running.
    @property bool isRunning ()
    {
        return isRunning_;
    }

    /// Gets the terminal.
    @property Terminal mainTerminal ()
    {
        return mainTerminal_;
    }

    /// Gets/sets the main menu.
    @property Menu mainMenu ()
    {
        return mainMenu_;
    }
    
    /// Ditto
    @property Menu mainMenu (Menu menu)
    {
        if (menu is mainMenu)
            return menu;
        
        auto prevMenu = mainMenu;
        mainMenu_ = menu;
        
        if (prevMenu !is null)
            prevMenu.onResignedAsMainMenu(new Event);
        
        menu.onBecameMainMenu(new Event);
        mainTerminal.add(menu);
        menu.visible = true;
        
        return mainMenu;
    }

    /**
     * Gets/sets this delegate is called before the application terminates, if the
     * delegate returns true the application will continue to terminate. Otherwise
     * the termination will stop and control is handed back to the main event loop
     *
	 * Params:
     *     Application = the application that called the delegate
     *     Responder = the responder that initiated the termination request
     *
	 * See_Also:
	 *  $(UL
	 *      $(LI $(LREF willTerminate))
	 *      $(LI $(LREF terminate))
	 *  )
     */
    @property bool delegate (Application, Responder) shouldTerminate ()
    {
        return shouldTerminate_;
    }

	/**
	 * Starts the main event loop.
	 *
	 * The loop continues until the stop or terminate method is called. Upon each
	 * iteration through the loop, the next available event from the window server is
	 * stored and then dispatched by calling the sendEvent method.
	 *
	 * After creating the Application object, the main function should start the event loop
	 * by calling run method on the Application object.
	 */
	void run ()
	{
	    mainTerminal.redraw();
	    isRunning_ = true;
	    
	    while (isRunning_)
	    {
	        sendEvent(readAndTranslateEvent());
	        
	        foreach (e ; internalEventQueue)
	            sendEvent(e);
	        
	        internalEventQueue.length = 0;
	    }
	}

	/**
	 * Terminates the receiver and the main event loop.
	 *
	 * When invoked, this method performs several steps to process the termination request.
	 * Fist it calls the shouldTerminate delegate (if available), if the delegate returns
	 * $(D_CODE false) the termination process is aborted and control is handed back to
	 * the main event loop. If the delegate returns $(D_CODE true) this method triggers a
	 * will terminate event and then terminates the main event loop. Control is then handed
	 * back to the main function or the function that called the run method.
	 *
	 * Params:
     *     sender = typically, this parameter contains the object that initiated the
     *              termination request.
	 */
	void terminate (Responder sender)
	{
	    if (shouldTerminate)
	    {
	        if (shouldTerminate()(this, sender))
	        {
	            willTerminate(this, sender);
	            isRunning_ = false;
	        }
	    }
	    
	    else
	    {
	        willTerminate(this, sender);
	        isRunning_ = false;
	    }
	}

	/**
	 * Dispatches an event to other objects.
	 *
	 * You rarely invoke sendEvent directly, although you might want to override this method
	 * to perform some action on every event. sendEvent is called from the main event loop
	 * (the run method). sendEvent is the method that dispatches events to the appropriate
	 * responders, Application handles application events. Cursor and key events are forwarded
	 * to the appropriate Terminal object for further dispatching.
	 *
	 * Params:
     *     event = the event to dispatch
	 */
	void sendEvent (Event event)
	{
	    if (event.type == EventType.keyDown)
	    {
	        if (!mainTerminal.performKeyEquivalent(event))
	            mainTerminal.sendEvent(event);
	    }
	    
	    else
	        mainTerminal.sendEvent(event);
	}

	/**
	 * Adds the given event to the receiver's event queue for later processing. The event will
	 * be processed iteration in application loop.
	 * 
	 * Params:
	 *     event = the event to post
	 */
	void postEvent (Event event)
	{
	    internalEventQueue ~= event;
	}

    /**
     * Reads and translates events.
     *
     * This method reads events from the underlying event system and then translates
     * them into Event objects.
     *
     * Returns: the translated event.
     */
    protected Event readAndTranslateEvent ()
    {
        auto event = terminal.getNextEvent();
        auto e = new Event;
        
        e.point = event.position;
        e.type = EventType.keyDown;
        
        switch (event.key)
        {
            case KeyCode.ctrlSpace:
            	e.character = ' ';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlA:
            	e.character = 'a';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlB:
            	e.character = 'b';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlC:
            	e.character = 'c';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlD:
            	e.character = 'd';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlE:
            	e.character = 'e';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlF:
            	e.character = 'f';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlG:
            	e.character = 'g';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlH:
            	e.character = 'h';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlI:
            	e.character = 'i';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlJ:
            	e.character = 'j';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlK:
            	e.character = 'k';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlL:
            	e.character = 'l';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlN:
            	e.character = 'n';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlO:
            	e.character = 'o';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlP:
            	e.character = 'p';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlQ:
            	e.character = 'q';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlR:
            	e.character = 'r';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlS:
            	e.character = 's';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlT:
            	e.character = 't';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlU:
            	e.character = 'u';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlV:
            	e.character = 'v';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlW:
            	e.character = 'w';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlX:
            	e.character = 'x';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlY:
            	e.character = 'y';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;

            case KeyCode.ctrlZ:
            	e.character = 'z';
            	e.stateMask = Key.ctrl;
            	e.keyCode = e.stateMask | e.character;
            break;
            
            case KeyCode.f1: e.keyCode = Key.f1; break;
            case KeyCode.f2: e.keyCode = Key.f2; break;
            case KeyCode.f3: e.keyCode = Key.f3; break;
            case KeyCode.f4: e.keyCode = Key.f4; break;
            case KeyCode.f5: e.keyCode = Key.f5; break;
            case KeyCode.f6: e.keyCode = Key.f6; break;
            case KeyCode.f7: e.keyCode = Key.f7; break;
            case KeyCode.f8: e.keyCode = Key.f8; break;
            case KeyCode.f9: e.keyCode = Key.f9; break;
            case KeyCode.f10: e.keyCode = Key.f10; break;
            case KeyCode.f11: e.keyCode = Key.f11; break;
            case KeyCode.f12: e.keyCode = Key.f12; break;
            case KeyCode.f13: e.keyCode = Key.f13; break;
            case KeyCode.f14: e.keyCode = Key.f14; break;
            case KeyCode.help: e.keyCode = Key.f15; break;
            case KeyCode.execute: e.keyCode = Key.f16; break;
            case KeyCode.f17: e.keyCode = Key.f17; break;
            case KeyCode.f18: e.keyCode = Key.f18; break;
            case KeyCode.f19: e.keyCode = Key.f19; break;
            case KeyCode.home: e.keyCode = Key.home; break;
            case KeyCode.insert: e.keyCode = Key.insert; break;
            case KeyCode.delete_: e.keyCode = Key.del; break;
            case KeyCode.end: e.keyCode = Key.end; break;
            case KeyCode.pageUp: e.keyCode = Key.pageUp; break;
            case KeyCode.pageDown: e.keyCode = Key.pageDown; break;
            
            case KeyCode.up:
            	e.keyCode = Key.arrowUp;
            	e.type = EventType.cursorMove;
            break;

            case KeyCode.down:
            	e.keyCode = Key.arrowDown;
            	e.type = EventType.cursorMove;
            break;

            case KeyCode.left:
            	e.keyCode = Key.arrowLeft;
            	e.type = EventType.cursorMove;
            break;

            case KeyCode.right:
            	e.keyCode = Key.arrowRight;
            	e.type = EventType.cursorMove;
            break;
            
            case KeyCode.keypadMultiple: e.keyCode = Key.keypadMultiply; break;
            case KeyCode.keypadPlus: e.keyCode = Key.keypadAdd; break;
            case KeyCode.keypadDivide: e.keyCode = Key.keypadDivide; break;
            case KeyCode.keypad0: e.keyCode = Key.keypad0; break;
            case KeyCode.keypad1: e.keyCode = Key.keypad1; break;
            case KeyCode.keypad2: e.keyCode = Key.keypad2; break;
            case KeyCode.keypad3: e.keyCode = Key.keypad3; break;
            case KeyCode.keypad4: e.keyCode = Key.keypad4; break;
            case KeyCode.keypad5: e.keyCode = Key.keypad5; break;
            case KeyCode.keypad6: e.keyCode = Key.keypad6; break;
            case KeyCode.keypad7: e.keyCode = Key.keypad7; break;
            case KeyCode.keypad8: e.keyCode = Key.keypad8; break;
            case KeyCode.keypad9: e.keyCode = Key.keypad9; break;
            case KeyCode.keypadMinus: e.keyCode = Key.keypadSubtract; break;
            case KeyCode.keypadComma: e.keyCode = Key.keypadDecimal; break;
            case KeyCode.enter: e.keyCode = Key.keypadCr; break;
			case KeyCode.del: e.keyCode = Key.backspace; break;
			
			default:
			    if (isWhite(event.key))
			    {
			        e.character = cast(dchar) event.key;
			        e.keyCode = event.key;
			        e.type = EventType.firstKeyDown;
			    }
			    
			    else if (isAlpha(event.key))
			    {
			        e.character = cast(dchar) event.key;
			        e.keyCode = event.key;
			    }
			    
			    else
			        e.keyCode = event.key;
        }
        
        return e;
    }
}