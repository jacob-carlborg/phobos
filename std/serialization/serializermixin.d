/**
 * Copyright: Copyright (c) 2013 Jacob Carlborg.
 * Authors: Jacob Carlborg
 * Version: Initial created: Sep 4, 2013
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 *
 * Source: $(PHOBOSSRC std/serialization/_serializermixin.d)
 *
 * Macros:
 *  XREF3 = <a href="std_$1_$2.html#$3">$(D std.$1.$2.$3)</a>
 *  XREF4 = <a href="std_$1_$2_$3.html#$4">$(D std.$1.$2.$3.$4)</a>
 */
module std.serialization.serializermixin;

import std.traits : isPointer;

package:

mixin template SerializerMixin ()
{
    private bool isBaseClass (T) (T value)
    {
        return value.classinfo !is T.classinfo;
    }

    private Id nextId ()
    {
        return idCounter++;
    }

    private string nextKey ()
    {
        return toData(keyCounter++);
    }

    private void resetCounters ()
    {
        keyCounter = 0;
        idCounter = 0;
    }

    private string toData (T) (T value)
    {
        return to!(string)(value);
    }

    private void triggerEvent (alias event, T) (T value)
    {
        static assert (isObject!(T) || isStruct!(T), format!(`The given value of the type "`, T, `" is not a valid type, the only valid types for this method are objects and structs.`));

        foreach (m ; __traits(allMembers, T))
        {
            mixin("alias attrs = getAttributes!(T." ~ m ~ ");");

            static if (attrs.contains!(event)())
                __traits(getMember, value, m)();
        }
    }

    private static bool isNonSerialized (T) ()
    {
        return getAttributes!(T).contains!(nonSerialized)();
    }

    private void error (string message, size_t line = __LINE__)
    {
        if (errorCallback)
            errorCallback()(new SerializationException(message, __FILE__, line));
    }
}

/*
 * This struct is a type independent representation of a slice. This struct is used
 * when sending a slice for archiving from the serializer to the archive.
 */
struct Slice
{
    /// The length of the slice.
    size_t length;

    /// The offset of the slice, i.e. where the slice begins in the array.
    size_t offset;

    /// The id of the slice. (Only used during unarchiving).
    size_t id = size_t.max;
}

/*
 * This struct is a type independent representation of an array. This struct is used
 * when sending an array for archiving from the serializer to the archive.
 */
struct Array
{
    /// The start address of the array
    const(void)* ptr;

    /// The length of the array
    size_t length;

    /// The size of an individual element stored in the array, in bytes.
    size_t elementSize;

    /**
     * Returns true if the given array is a slice of the receiver.
     *
     * Params:
     *     b = the array to check if it's a slice
     *
     * Returns: true if the given array is a slice of the receiver.
     */
    bool isSliceOf (Array b)
    {
        return ptr >= b.ptr && ptr + length * elementSize <= b.ptr + b.length * b.elementSize;
    }
}

// Evaluates to true if $(D_PARAM T) is a primitive type.
template isPrimitive (T)
{
    enum bool isPrimitive = is(T == bool) ||
                        is(T == byte) ||
                        is(T == cdouble) ||
                        //is(T == cent) ||
                        is(T == cfloat) ||
                        is(T == char) ||
                        is(T == creal) ||
                        is(T == dchar) ||
                        is(T == double) ||
                        is(T == float) ||
                        is(T == idouble) ||
                        is(T == ifloat) ||
                        is(T == int) ||
                        is(T == ireal) ||
                        is(T == long) ||
                        is(T == real) ||
                        is(T == short) ||
                        is(T == ubyte) ||
                        //is(T == ucent) ||
                        is(T == uint) ||
                        is(T == ulong) ||
                        is(T == ushort) ||
                        is(T == wchar);
}

// Evaluates to true if $(D_PARAM T) is class.
template isClass (T)
{
    enum bool isClass = is(T == class);
}

// Evaluates to true if $(D_PARAM T) is an interface.
template isInterface (T)
{
    enum bool isInterface = is(T == interface);
}

// Evaluates to true if $(D_PARAM T) is a class or an interface.
template isObject (T)
{
    enum bool isObject = isClass!(T) || isInterface!(T);
}

// Evaluates to true if $(D_PARAM T) is an object or a pointer.
template isReference (T)
{
    enum bool isReference = isObject!(T) || isPointer!(T);
}

// Evaluates to true if $(D_PARAM T) is an enum.
template isEnum (T)
{
    enum bool isEnum = is(T == enum);
}

// Evaluates to true if $(D_PARAM T) is a typedef.
template isTypedef (T)
{
    enum bool isTypedef = is(T == typedef);
}

// Evaluates to true if $(D_PARAM T) is void.
template isVoid (T)
{
    enum bool isVoid = is(T == void);
}

// Evaluates to true if $(D_PARAM T) is a struct.
template isStruct (T)
{
    enum isStruct = is(T == struct);
}

// Evaluates the type of the element of the array.
template ElementTypeOfArray(T : T[])
{
    alias T ElementTypeOfArray;
}

// Evaluates to the base type of the enum.
template BaseTypeOfEnum (T)
{
    static if (is(T U == enum))
        alias BaseTypeOfEnum!(U) BaseTypeOfEnum;

    else
        alias T BaseTypeOfEnum;
}