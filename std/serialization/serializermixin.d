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

package:

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