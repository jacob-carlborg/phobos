/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Mar 12, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/internal/terminal/_posix.d)
 */
module std.internal.terminal.terminal;

version (Posix)
    public import std.internal.terminal.posix;