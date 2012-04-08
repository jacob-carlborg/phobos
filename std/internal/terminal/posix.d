/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Mar 12, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/internal/terminal/_posix.d)
 */
module std.internal.terminal.posix;

import core.stdc.signal;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import core.sys.posix.signal;
import core.sys.posix.sys.ioctl;
import core.sys.posix.sys.ttycom;
import core.sys.posix.termios;
import core.sys.posix.unistd;

import std.cstream;
import std.conv;
import std.process;
import std.stdio;
import std.utf;

import std.internal.terminal.terminal;

import std.terminal.geometry.point;
import std.terminal.geometry.rect;
import std.terminal.geometry.size;

import std.terminal.graphics.color;

private
{
	alias core.stdc.stdio.stdin stdin;
	alias core.stdc.stdio.fileno fileno;
	alias core.stdc.stdio.stdout stdout;
}

Terminal terminal;

static this ()
{
    terminal = Terminal.instance();
}

final class Terminal
{
    private static Terminal instance_;

    static Terminal instance ()
    {
        return instance_ = instance_ ? instance_ : new Terminal;
    }
    
    private this ()
    {
        initTerminal();
    }
    
    ~this ()
    {
        resetTerminal();
    }
    
	Event getNextEvent ()
	{
		Event event;

		event.key = cast(KeyCode) readKey();
		event.position = getCursorPosition();
		
		return event;
	}
	
	void clearScreen ()
	{
		writef(capaTable[Clear.screen]);
	}
	
	void clearInFront ()
	{
		writef(capaTable[Clear.beginningOfDisplay]);
	}
	
	void clearBehind ()
	{
		writef(capaTable[Clear.endOfDisplay]);
	}
	
	void clearRow ()
	{
		writef(capaTable[Clear.row]);
	}
	
	void clearRowInFront ()
	{
		writef(capaTable[Clear.beginningOfRow]);
	}
	
	void clearRowBehind ()
	{
		writef(capaTable[Clear.endOfRow]);
	}
	
	void moveCursor (Point position)
	{
		moveCursor(position.y, position.x);
	}
	
	void moveCursor (int x, int y)
	{
		writef(capaTable[Cursor.move], x, y);
	}
	
	void changeScrollRegion (Point position)
	{
		writef(capaTable[CapaIndex.changeScrollRegion]);
	}
	
	void moveCursorDown (int rows = 1)
	{
		writef(capaTable[Cursor.down], rows);
	}
	
	void moveCursorLeft (int columns = 1)
	{
		writef(capaTable[Cursor.left], columns);
	}
	
	void moveCursorRight (int columns = 1)
	{
		writef(capaTable[Cursor.right], columns);
	}
	
	void moveCursorUp (int rows = 1)
	{
		writef(capaTable[Cursor.up], rows);
	}
	
	Point getCursorPosition ()
	{
		string buffer;

		buffer.reserve(10);
		writef(capaTable[Cursor.position]);
		
		do
		{
		    buffer ~= din.getc();
		} while (buffer[$ - 1] != 'R');
		
		buffer ~= '\0';
		
		int row;
		int column;
		
		sscanf(buffer.ptr, capaTable[Cursor.answer], &column, &row);
		
		return Point(column, row);
	}
	
	void insertCharacter (dchar c)
	{
		writef(capaTable[Character.insert], 1);
		write(c);
	}
	
	void insertString (string str)
	{
		writef(capaTable[Character.insert], str.length);
		write(str);
	}
	
	void insertBlankLines (int lines = 1)
	{
		writef(capaTable[CapaIndex.insertLines], lines);
	}
	
	void deleteCharacters (int characters = 1)
	{
		writef(capaTable[Character.delete_], characters);
	}
	
	void clearCharacters (int characters = 1)
	{
		writef(capaTable[Character.erase], characters);
	}
	
	void deleteLines (int lines = 1)
	{
		writef(capaTable[CapaIndex.deleteLines]);
	}
	
	void scrollUp (int rows = 1)
	{
		writef(capaTable[Scroll.up], rows);
	}
	
	void scrollDown (int rows = 1)
	{
		writef(capaTable[Scroll.down], rows);
	}
	
	void saveCursor ()
	{
		writef(capaTable[Cursor.save]);
	}
	
	void restoreCursor ()
	{
		writef(capaTable[Cursor.restore]);
	}
	
	void bold ()
	{
		writef(capaTable[Mode.bold]);
	}
	
	void reverse ()
	{
		writef(capaTable[Mode.reverse]);
	}
	
	void underline ()
	{
		writef(capaTable[Mode.underline]);
	}
	
	void normal ()
	{
		writef(capaTable[Mode.normal]);
	}
	
	void foregroundColor (Color color)
	{
		writef(capaTable[CapaIndex.foregroundColor]);
	}
	
	void backgroundColor (Color color)
	{
		writef(capaTable[CapaIndex.backgroundColor]);
	}
	
	void horizontalLine (Point position, int length)
	{
		auto currentPosition = getCursorPosition();
		moveCursor(position);
		graphicsOn();
		
		foreach (i ; 0 .. length + 1)
		    horizontal();
	
	    graphicsOff();
	    moveCursor(currentPosition);
	}
	
	void verticalLine (const ref Point position, int length)
	{
        auto currentPosition = getCursorPosition();
        moveCursor(position);
        graphicsOn();
        
        foreach (i ; 0 .. length + 1)
        {
            moveCursor(position.x, i);
            vertical();
        }
        
        graphicsOff();
        moveCursor(currentPosition);
	}
	
	void box (const ref Rect rectangle)
	{
		auto currentPosition = getCursorPosition();
		graphicsOn();
		moveCursor(rectangle.position);
		upperLeftCorner();
		
		int x1 = rectangle.position.x;
		int y1 = rectangle.position.y;
		int x2 = rectangle.position.x + rectangle.size.width;
		int y2 = rectangle.position.y + rectangle.size.height;
		
		foreach (i ; x1 + 1 .. x2)
		    horizontal();
		    
		upperRightCorner();
		
		foreach (i ; y1 + 1 .. y2)
		{
		    moveCursor(x2, i);
		    vertical();
		}
		
		moveCursor(x2, y2);
		lowerRightCorner();
		
		for (int i = x2 - 1; i > x1; i--)
		{
		    moveCursor(i, y2);
		    horizontal();
		}
		
		moveCursor(x1, y2);
		lowerLeftCorner();
		
		for (int i = y2 - 1; i > y1; i--)
		{
		    moveCursor(x1, i);
		    vertical();
		}
		
		graphicsOff();
		moveCursor(currentPosition);
	}
	
	void table (const ref Point position, const int[] rows, const int[] columns)
	{
		int r = 1;
		auto x = position.x;
		auto y = position.y;
		auto currentPosition = getCursorPosition();

		graphicsOn();
		moveCursor(position);
		upperLeftCorner();
		
		foreach (i, tc ; columns)
		{
		    foreach (sc ; 0 .. tc)
		        horizontal();
		        
		    if (i < columns.length - 1)
		        top();
		        
		    else
		        upperRightCorner();
		}
		
		foreach (i, tr ; rows)
		{
		    foreach (sr ; 0 .. tr)
		    {
		        int c = 0;

		        foreach (tc ; 0 .. columns.length + 1)
		        {
		            moveCursor(x + c, y + r);
		            vertical();
		            c += columns[tc] + 1;
		        }
		        
		        r++;
		    }
		    
		    if (tr < rows.length - 1)
		    {
		        moveCursor(x, y + r);
		        left();
		        
		        foreach (tc ; columns)
		        {
		            foreach (sc ; 0 .. tc)
		                horizontal();
		                
		            if (tc < columns.length - 1)
		                cross();
		                
		            else
		                right();
		        }
		    }
		    
		    else
		    {
		        moveCursor(x, y + r);
		        lowerLeftCorner();
		        
		        foreach (tc ; columns)
		        {
		            foreach (sc ; 0 .. tc)
		                horizontal();
		                
		            if (tc < columns.length - 1)
		                bottom();
		                
		            else
		                lowerRightCorner();
		        }
		    }
		    
		    r++;
		}
		
		graphicsOff();
		moveCursor(currentPosition);
	}
	
	@property int width ()
	{
		return columns;
	}
	
 	@property int height ()
	{
		return rows;
	}
	
	@property bool changed ()
	{
		bool result = sizeChanged;
		sizeChanged = false;
		
		return result;
	}
	
	void onResize (void function () func)
	{
		draw = func;
	}
	
	void setSize (Size size)
	{
	    setSize(size.width, size.height);
	}
	
	void setSize (int width, int height)
	{
		writef(capaTable[CapaIndex.resizeWindow], rows, columns);
		getWindowSize();
	}
}

private:

enum undefinedFunctionKey = 400;

enum functionKeyTable = [
    "[11~",  /* F1 */
    "[12~",	 /* F2 */
    "[13~",	 /* F3 */
    "[14~",	 /* F4 */
    "[15~",	 /* F5 */
    "[17~",	 /* F6 */
    "[18~",	 /* F7 */
    "[19~",	 /* F8 */
    "[20~",	 /* F9 */
    "[21~",	 /* F10 */
    "[23~",  /* F11 */
    "[24~",	 /* F12 */
    "[25~",	 /* F13 */
    "[26~",	 /* F14 */
    "[28~",	 /* Help */
    "[29~",	 /* Utför */
    "[31~",	 /* F17 */
    "[32~",	 /* F18 */
    "[33~",	 /* F19 */
    "[34~",	 /* F20 */
    "[1~",	 /* Home (gamla Sök) */
    "[2~",	 /* Insert */
    "[3~",	 /* Delete */
    "[4~",	 /* End (gamla Välj ut) */
    "[5~",	 /* Pageup (gamla Föreg) */
    "[6~",	 /* Pagedown (gamla Nästa) */
    "OA",	 /* Up */
    "OB",	 /* Down */
    "OD",	 /* Left */
    "OC",	 /* Right */
    "OP",	 /* PF1 */
    "OQ",	 /* PF2 */
    "OR",	 /* PF3 */
    "OS",	 /* PF4 */
    "Oj",    /* NKP x */
    "Ok",    /* NKP + */
    "Oo",    /* NKP / */
    "Op",	 /* NKP 0 */
    "Oq",	 /* NKP 1 */
    "Or",	 /* NKP 2 */
    "Os",	 /* NKP 3 */
    "Ot",	 /* NKP 4 */
    "Ou",	 /* NKP 5 */
    "Ov",	 /* NKP 6 */
    "Ow",	 /* NKP 7 */
    "Ox",	 /* NKP 8 */
    "Oy",	 /* NKP 9 */
    "Om",	 /* NKP - */
    "Ol",	 /* NKP , */
    "On",	 /* NKP . */
    "OM"	 /* NKP Enter */
];

enum FunctionKey
{
    f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13, f14,
    help, execute, f17, f18, f19, f20, home, insert, delete_, end,
    pageUp, pageDown, up, down, left, right, pf1, pf2, pf3, pf4,
    nkpMultiple, nkpPlus, nkpDivide, nkp0, nkp1, nkp2, nkp3, nkp4,
    nkp5, nkp6, nkp7, nkp8, nkp9, nkpMinus, nkpComma, nkpPeriod,
    nkpEnter
}

struct Replacement
{
    FunctionKey key;
    string str;
}

enum xtermTable = [
    Replacement(FunctionKey.f1, "OP"),
    Replacement(FunctionKey.f2, "OQ"),
    Replacement(FunctionKey.f3, "OR"),
    Replacement(FunctionKey.f4, "OS"),
    Replacement(FunctionKey.home, "OH"),
    Replacement(FunctionKey.end, "OF")
];

enum linuxTable = [
    Replacement(FunctionKey.f1, "[[A"),
    Replacement(FunctionKey.f2, "[[B"),
    Replacement(FunctionKey.f3, "[[C"),
    Replacement(FunctionKey.f4, "[[D"),
    Replacement(FunctionKey.f5, "[[E"),
];

enum gc = ["jklmnqtuvwx", "gtrf/,5687."];

struct Replacements
{
    string type;
    Replacement[] replace;
    int tix;
}

enum replacementTable = [
    Replacements("vt220", null, 1),
    Replacements("xterm", xtermTable, 0),
    Replacements("xterm-color", xtermTable, 0),
    Replacements("linuxTable", linuxTable, 0)
];

int toInt (T) (T t)
{
    return cast(int) t;
}

enum string[int] capaTable = [
    toInt(Clear.endOfDisplay) : "\033[J",                 /* Clear to end of display */
    toInt(Clear.beginningOfDisplay) : "\033[1J",                /* Clear from beginning of display */
    toInt(Clear.endOfRow) : "\033[0K",                /* Clear to end of line    */
    toInt(Clear.beginningOfRow) : "\033[1K",                /* Clear beginning of line  */
    toInt(Clear.row) : "\033[2K",                /* Clear line              */
    toInt(Clear.screen) : "\033[;H\033[2J",         /* Clear screen            */
	toInt(Clear.tab) : "\033[3g",                /* Clear all tab stops     */

    toInt(Cursor.move) : "\033[%d;%dH",            /* Cursor motion           */
    toInt(Cursor.down) : "\033[%dB",               /* Move down one line      */
    toInt(Cursor.home) : "\033[H",                 /* Home cursor             */
    toInt(Cursor.right) : "\033[%dC",               /* Move cursor left one character */
    toInt(Cursor.left) : "\033[%dD",               /* Move cursor left one character */
    toInt(Cursor.up) : "\033[%dA",               /* Up one line             */
    toInt(Cursor.position) : "\033[6n",                /* Request Cursor Position */
    toInt(Cursor.answer) : "\033[%d;%dR",            /* Cursor Position Answer */
    toInt(Cursor.save) : "\0337",                  /* Save cursor and attributes */
    toInt(Cursor.restore) : "\0338",                  /* Restore cursor and attributes */

    toInt(Mode.keypadTransmitOff) : "\033[?1l\033>",          /* Out of keypad transmit mode */
    toInt(Mode.keypadTransmitOn) : "\033[?1h\033=",          /* Keypad transmit mode on */
    toInt(Mode.blinking) : "\033[5m",                /* Turn on blinking        */
    toInt(Mode.bold) : "\033[1m",                /* Enter bold mode         */
    toInt(Mode.normal) : "\033[m",                 /* Enter normal mode       */
    toInt(Mode.reverse) : "\033[7m",                /* Enter reverse mode      */
    toInt(Mode.underline) : "\033[4m",                /* Start underline mode   */
    toInt(Mode.autoRepeat) : "\033[?8h",               /* Auto-repeat keys */

    //toInt(Mode.normal) : "\033[m",                 /* End stand-out mode      */
    //Mode.highlightOn"\033[7m",                /* Begin stand-out mode    */
    //toInt(Mode.normal) : "\033[m",                 /* End underline mode     */

    toInt(Scroll.reverse) : "\033[M",                 /* Scroll reverse          */
	toInt(Scroll.up) : "\033[%dS",               /* Scroll up */
	toInt(Scroll.down) : "\033[%dT",               /* Scroll down */


	toInt(Graphics.set) : "\033)0",                 /* Choose graphics as G1 */
	toInt(Graphics.on) : "\016",                   /* Switch to G1 (graphics) */
	toInt(Graphics.next) : "\033N",                  /* Switch to G2 (graphics) next char only */
	toInt(Graphics.off) : "\017",                   /* Switch to G0 (normal) */

    toInt(Character.insert) : "\033[%d@",               /* Insert characters */
    toInt(Character.delete_) : "\033[%dP",               /* Delete characters */
    toInt(Character.erase) : "\033[%dX",               /* Erase characters  */

    toInt(CapaIndex.changeScrollRegion) : "\033[%d;%dr",            /* Change scrolling region */    
    toInt(CapaIndex.initialization) : "\033[1;%dr\033[%d;1H",   /* Initialization string   */
    toInt(CapaIndex.nonDestructiveSpace) : "\033[%dC",               /* Nondestructive space    */
    toInt(CapaIndex.foregroundColor) : "\033[3%dm",              /* Set foreground color */
    toInt(CapaIndex.backgroundColor) : "\033[4%dm",              /* Set background color */
    toInt(CapaIndex.insertLines) : "\033[%dL",               /* Insert lines */
    toInt(CapaIndex.deleteLines) : "\033[%dM",               /* Delete lines */
    toInt(CapaIndex.resizeWindow) : "\033[8;%d;%dt"           /* Resize window */
];

enum Clear
{
	endOfDisplay, beginningOfDisplay, endOfRow, beginningOfRow, row, screen,
	tab
}

enum Cursor
{
	move = Clear.tab + 1, down, home, left, up, right, position, save, restore,
	answer
}

enum Mode
{
	keypadTransmitOn = Cursor.answer + 1, keypadTransmitOff, blinking, bold, normal,
	reverse, characterAttributesOff, underline, autoRepeat
}

enum Scroll
{
	reverse = Mode.autoRepeat + 1, up, down
}

enum Graphics
{
	set = Scroll.down + 1, on, off, next
}

enum Character
{
	insert = Graphics.next + 1, delete_, erase
}

enum CapaIndex
{
	changeScrollRegion = Character.erase + 1, initialization, nonDestructiveSpace,
	resizeWindow, deleteLines, insertLines, foregroundColor, backgroundColor, 
}

enum Box
{
	leftRight, upRight, upLeft, lowerLeft, cross, horizontal, left, right,
	bottom, top, vertical
}

int tx;
int rows = 24;
int columns = 80;

bool _graphicsOn;
bool sizeChanged;

termios savedTerminal;
void function () draw;

size_t tix (string str)
{
	foreach (i, replacement ; replacementTable)
		if (str == replacement.type)
			return i;

	return 0;
}

unittest
{
	assert(tix("vt220") == 0);
	assert(tix("xterm") == 1);
	assert(tix("xterm-color") == 2);
	assert(tix("line") == 0);
}

void replace (size_t ix)
{
	auto replacement = replacementTable[ix];
	tx = replacement.tix;
	
	foreach (i ; 0 .. replacement.replace.length)
	{
		auto r = replacement.replace[i];
		functionKeyTable[r.key] = r.str;
	}
}

unittest
{
    void test (int index, int secIndex, string expectedValue)
    {
        replace(index);
        auto replacement = replacementTable[index];
        
        auto r = replacement.replace[secIndex];
    	assert(functionKeyTable[r.key], expectedValue);
    }
    
    test(1, 0, "OP");
    test(1, 1, "OQ");
    test(1, 2, "OR");
    test(1, 3, "OS");
    test(1, 4, "OH");
    test(1, 5, "OF");
    
    test(2, 0, "OP");
    test(2, 1, "OQ");
    test(2, 2, "OR");
    test(2, 3, "OS");
    test(2, 4, "OH");
    test(2, 5, "OF");
    
    test(3, 0, "[[A");
    test(3, 1, "[[B");
    test(3, 2, "[[C");
    test(3, 3, "[[D");
    test(3, 4, "[[E");
}

void resetTerminal ()
{
	writef(capaTable[CapaIndex.initialization], rows, rows);
	writef(capaTable[Graphics.off]);
	writef(capaTable[Mode.normal]);
	tcsetattr(fileno(stdin), TCSAFLUSH, &savedTerminal);
}

extern (C) void onCtrlC (int sig)
{
    resetTerminal();
    exit(0);
}

extern (C) void onError (int sig)
{
    resetTerminal();
    signal(sig, SIG_DFL);
}

void getWindowSize ()
{
    winsize windowSize;
    ioctl(fileno(stdin), TIOCGWINSZ, &windowSize);
    rows = windowSize.ws_row;
    columns = windowSize.ws_col;
}

extern (C) void onWindowResize (int sig)
{
    getWindowSize();
    sizeChanged = 1;

    if (draw)
        draw();
}

void initTerminal ()
{
    termios outTerminal;

    setbuf(stdin, null);
    auto ix = tix(std.process.getenv("TERM"));

    replace(ix);
    tcgetattr(fileno(stdin), &savedTerminal);

    outTerminal = savedTerminal;
    outTerminal.c_lflag &= ~(ECHO | ICANON);
    outTerminal.c_iflag &= ~ICRNL;
    outTerminal.c_cc[VMIN] = 1;
    outTerminal.c_cc[VTIME] = 0;
    tcsetattr(fileno(stdin), TCSANOW, &outTerminal);
    getWindowSize();

    writef(capaTable[Mode.keypadTransmitOn]);
    writef(capaTable[CapaIndex.initialization], rows, rows);
    writef(capaTable[Graphics.set]);
    writef(capaTable[Mode.autoRepeat]);
    
    signal(SIGINT, &onCtrlC);
    signal(SIGBUS, &onError);
    signal(SIGSEGV, &onError);
    signal(SIGWINCH, &onWindowResize);
}

size_t functionKeyCode (string key)
{
	foreach (i, k ; functionKeyTable)
	{
		if (k == key)
			return 256 + i;

		string b = k;
		
		if (k.length >= key.length)
			b = k[0 .. key.length];
		
		if (key == b)
			return 0;
	}
	
	return undefinedFunctionKey;
}

unittest
{
	auto results = [
		256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 267, 268, 269,
		270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283,
		284, 285, 286, 287, 288, 289, 290, 291, 292, 293, 294, 295, 296, 297,
		298, 299, 300, 301, 302, 303, 304, 305, 306
	];
	
	assert(results.length == functionKeyTable.length);
	
	foreach (i, k ; functionKeyTable)
		assert(functionKeyCode(k) == results[i]);

	assert(functionKeyCode("[1") == 0);
	assert(functionKeyCode("O") == 0);

	assert(functionKeyCode("foo") == undefinedFunctionKey);
	assert(functionKeyCode("bar") == undefinedFunctionKey);
}

size_t readKey ()
{
    auto c = din.readChar();

    if (c != '\033')
        return c;
    
    string buffer;
    buffer.reserve(512);

    size_t result;

    do
    {
        buffer ~= din.readChar();
        result = functionKeyCode(buffer);
    } while (!result);

    return result;
}

void graphicsOn ()
{
	writef(capaTable[Graphics.on]);
	_graphicsOn = true;
}

void graphicsOff ()
{
	writef(capaTable[Graphics.off]);
	_graphicsOn = false;
}

void silentlyEnableGraphics ()
{
	if (!_graphicsOn)
		writef(capaTable[Graphics.on]);
}

void lowerRightCorner ()
{
	graphics(Box.leftRight);
}

void upperRightCorner ()
{
	graphics(Box.upRight);
}

void upperLeftCorner ()
{
	graphics(Box.upLeft);
}

void lowerLeftCorner ()
{
	graphics(Box.lowerLeft);
}

void cross ()
{
	graphics(Box.cross);
}

void left ()
{
	graphics(Box.left);
}

void right ()
{
	graphics(Box.right);
}

void bottom ()
{
	graphics(Box.bottom);
}

void top ()
{
	graphics(Box.top);
}

void horizontal ()
{
	graphics(Box.horizontal);
}

void vertical ()
{
	graphics(Box.vertical);
}

void graphics (Box box)
{
	silentlyEnableGraphics();
	write(gc[tx][box]);
}