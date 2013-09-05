/**
 * Copyright: Copyright (c) 2010-2013 Jacob Carlborg.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 26, 2010
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 *
 * Source: $(PHOBOSSRC std/serialization/_serializable.d)
 */
module std.serialization.serializable;

import std.serialization.attribute;
import std.serialization.archivers.archiver;
import std.serialization.events;
import std.serialization.serializer;

/**
 * This interface represents a type that this is serializable. To implement this interface
 * the user needs to implement two methods, one for serialization and one for
 * deserialization. These methods are used to perform custom (de)serialization and will
 * be called if available. It's up to these methods to call the serializer to perform
 * the (de)serialization. If these methods are available the automatic (de)serialization
 * process $(I will not) be performed.
 *
 * These methods can also be used without actually implementing this interface, i.e. they
 * also work for structs.
 *
 * Examples:
 * ---
 * class Foo : Serializable
 * {
 *  int a;
 *
 *  void toData (Serializer serializer, Serializer.Data key)
 *  {
 *      serializer.serialize(a, "b");
 *  }
 *
 *  void fromData (Serializer serializer, Serializer.Data key)
 *  {
 *      a = serializer.deserialize!(int)("b");
 *  }
 * }
 * ---
 *
 * See_Also: $(LREF isSerializable)
 */
interface Serializable
{
    /**
     * Called by the given serializer when performing custom serialization.
     *
     * Params:
     *     serializer = the serializer that performs the serialization
     *     key = the key of the receiver
     *
     * See_Also: $(LREF fromData)
     */
    void toData (Serializer serializer, Serializer.Data key);

    /**
     * Called by the given serializer when performing custom deserialization.
     *
     * Params:
     *     serializer = the serializer that performs the deserialization
     *     key = the key of the receiver
     *
     * See_Also: $(LREF toData)
     */
    void fromData (Serializer serializer, Serializer.Data key);
}

/**
 * Evaluates to $(D_KEYWORD true) if the given type is serializable. A type is considered
 * serializable when it implements the to two methods in the Serializable interface.
 * Note that the type does not have to implement the actual interface, i.e. it also works
 * for structs.
 *
 * Examples:
 * ---
 * struct Foo
 * {
 *  int a;
 *
 *  void toData (Serializer serializer, Serializer.Data key)
 *  {
 *      serializer.serialize(a, "b");
 *  }
 *
 *  void fromData (Serializer serializer, Serializer.Data key)
 *  {
 *      a = serializer.deserialize!(int)("b");
 *  }
 * }
 *
 * static assert(isSerializable!(Foo));
 * ---
 *
 * See_Also: $(LREF Serializable)
 */
template isSerializable (T)
{
    enum isSerializable = is(T : Serializable) || (
        is(typeof(T.toData(Serializer.init, Serializer.Data.init))) &&
        is(typeof(T.fromData(Serializer.init, Serializer.Data.init))));
}

/**
 * Indicates that the declaration this attribute is attached to should not be
 * (de)serialized.
 *
 * Examples:
 * ---
 * class Foo
 * {
 *     int a;
 *     @nonSerialized int b; // "b" will not be (de)serialized
 * }
 *
 * @nonSerialized struct Bar // "Bar" will not be (de)serialized
 * {
 *     int a;
 *     int b;
 * }
 * ---
 */
@attribute struct nonSerialized { }

/*
 * Converts a tuple of aliases to an array of strings containing the names of the given
 * aliases.
 *
 * Examples:
 * ---
 * int a;
 * int b;
 *
 * enum names = toArray!(a, b);
 *
 * static assert(names == ["a", "b"]);
 * ---
 *
 * Returns: an array containing the names of the given aliases
 */
static string[] toArray (Args ...) ()
{
    string[] args;

    foreach (i, _ ; typeof(Args))
        args ~= Args[i].stringof;

    return args;
}