/**
 * Copyright: Copyright (c) 2009-2012 Jacob Carlborg
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 22, 2009
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * Source: $(PHOBOSSRC std/terminal/_cursor.d)
 */
module std.terminal.cursor;

import std.internal.terminal.terminal : terminal;
import std.terminal.geometry.point;

final class Cursor
{    
    private static Cursor instance_;
    private Point[] savedPositions;
    
    private this () {}
    
    /// Returns an instance of the receiver. 
    @property static Cursor instance ()
    {
        return instance_ = instance_ ? instance_ : new Cursor;
    }
    
    @property Point position () const
    {
        auto p = terminal.getCursorPosition();
        return Point(p.x - 1, p.y - 1);
    }
    
    @property Point position (Point position)
    {
        move(position);
        return position;
    }
    
    /// Moves the cursor to the given position and returns the previous position.
    Point move (const ref Point position)
    {
        auto prevPosition = this.position;
        terminal.moveCursor(position);
        
        return prevPosition;
    }
    
    /// Moves the cursor $(I rows) rows up and returns the previous position.
	Point moveUp (int rows = 1)
	{
	    auto prevPosition = position;
	    terminal.moveCursorUp(rows);
	    
	    return prevPosition;
	}

	/// Moves the cursor $(I columns) columns to the left and returns the previous position.
	Point moveLeft (int columns = 1)
	{
	    auto prevPosition = position;
	    terminal.moveCursorLeft(columns);
	    
	    return prevPosition;
	}

	/// Moves the cursor $(I rows) rows down and returns the previous position.
	Point moveDown (int rows = 1)
	{
	    auto prevPosition = position;
	    terminal.moveCursorDown(rows);
	    
	    return prevPosition;
	}

	/// Moves the cursor $(I columns) columns to the right and returns the previous position.
	Point moveRight (int columns = 1)
	{
	    auto prevPosition = position;
	    terminal.moveCursorRight(columns);
	    
	    return prevPosition;
	}

	/// Deletes $(I characters) number of characters.
	void deleteCharacters (int characters = 1)
	{
	    terminal.deleteCharacters(characters);
	}

	/// Clears the screen.
	void clearScreen ()
	{
	    terminal.clearScreen();
	}

	/// Clears the screen in front of the cursor.
	void clearInFront ()
	{
	    terminal.clearInFront();
	}

	/// Clears the screen behind the cursor.
	void clearBehind ()
	{
	    terminal.clearBehind();
	}

	/// Clears the row where the cursor is.
	void clearRow ()
	{
	    terminal.clearRow();
	}

	/**
	 * Saves the current position of the cursor and returns a key representing the position,
	 * this can later be used to retrieve the position.
	 *
	 * Returns: a key representing the position
	 */
	size_t saveCurrentPosition ()
	{
	    savedPositions ~= position;
	    return savedPositions.length - 1;
	}

	/**
	 * Retrieves a previously stored position.
	 *
	 * Params:
     *     position = the key representing the stored position
     * 
	 * Throws: RangeError if the given key is out of bounds
	 */
	Point retrievePosition (size_t key)
	in
	{
	    assert(key < savedPositions.length);
	}
	body
	{
	    auto prevPosition = position;
	    auto pos = savedPositions[key];
	    move(pos);
	    
	    return prevPosition;
	}

	/// Clears all previously saved positions.
	void clearSavedPositions ()
	{
	    savedPositions.length = 0;
	}
}