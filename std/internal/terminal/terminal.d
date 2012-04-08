/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Mar 12, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/internal/terminal/_posix.d)
 */
module std.internal.terminal.terminal;

import std.terminal.geometry.point;

version (Posix)
    public import std.internal.terminal.posix;

struct Event
{
	Point position;
	KeyCode key;
}

enum KeyCode : size_t
{
	null_, ctrlSpace = 0, ctrlA, ctrlB, ctrlC, ctrlD, ctrlE, ctrlF, ctrlG,
	bell = 7, ctrlH, backspace = 8, ctrlI, tab = 9, ctrlJ, newline = 10, ctrlK,
	ctrlL, ctrlM, return_ = 13, enter = 13, ctrlN, ctrlO, ctrlP, ctrlQ, ctrlR,
	ctrlS, ctrlT, ctrlU, ctrlV, ctrlW, ctrlX, ctrlY, ctrlZ, escape, del = 127,
	rubout = 127,
	
	f1 = 256, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13, f14,
    help, execute, f17, f18, f19, f20, home, insert, delete_, end,
    pageUp, pageDown, up, down, left, right, pf1, pf2, pf3, pf4,
    keypadMultiple, keypadPlus, keypadDivide, keypad0, keypad1, keypad2,
    keypad3, keypad4, keypad5, keypad6, keypad7, keypad8, keypad9, keypadMinus,
    keypadComma, keypadPeriod, keypadEnter
}