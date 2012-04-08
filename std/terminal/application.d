/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 6, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/terminal/_application.d)
 */
module std.terminal.application;

import std.terminal.widgets.terminal;

class Menu
{
    void redraw () {}
}

class Application
{
    @property Menu mainMenu ()
    {
        return null;
    }
    
    @property static Application instance () { return null; }
}