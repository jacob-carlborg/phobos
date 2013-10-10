/**
 * Copyright: Copyright (c) 2010-2013 Jacob Carlborg.
 * Authors: Jacob Carlborg
 * Version: Initial created: Feb 6, 2010
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 *
 * Source: $(PHOBOSSRC std/serialization/archivers/_archive.d)
 */
module std.serialization.archivers.archiver;

import std.array;
import std.conv;
import std.serialization.archivers.archivermixin;
import std.serialization.deserializer;
import std.serialization.serializationexception;
import std.serialization.serializer;
import std.serialization.serializermixin;
import std.traits;
import std.utf;

static import std.string;

/**
 * This interface represents an archive. This is the interface all archive
 * implementations need to implement to be able to be used as an archive with the
 * serializer.
 *
 * The archive is the backend in the serialization process. It's independent of the
 * serializer and any archive implementation. Although there are a couple of
 * limitations of what archive types can be implemented (see below).
 *
 * The archive is responsible for archiving primitive types in the format chosen by
 * the archive implementation. The archive ensures that all types are properly
 * archived in a format that can be later unarchived.
 *
 * The archive can only handle primitive types, like strings, integers, floating
 * point numbers and so on. It can not handle more complex types like objects or
 * arrays; the serializer is responsible for breaking the complex types into
 * primitive types that the archive can handle.
 *
 * Implementing an Archive Type:
 *
 * There are a couple of limitations when implementing a new archive, this is due
 * to how the serializer and the archive interface is built. Except for what this
 * interface says explicitly an archive needs to be able to handle the following:
 *
 * $(UL
 *     $(LI unarchive a value based on a key or id, regardless of where in the archive
 *         the value is located)
 * $(LI most likely be able to modify already archived data)
 * $(LI structured formats like JSON, XML and YAML works best)
 * )
 *
 * If a method takes a delegate as one of its parameters that delegate should be
 * considered as a callback to the serializer. The archive need to make sure that
 * any archiving that is performed in the callback be a part of the type that is
 * currently being archived. This is easiest explained by an example:
 *
 * ---
 * void archiveArray (Array array, string type, string key, Id id, void delegate () dg)
 * {
 *     markBegningOfNewType("array");
 *     storeMetadata(type, key, id);
 *
 *     beginNewScope();
 *     dg();
 *     endScope();
 *
 *     markEndOfType();
 * }
 * ---
 *
 * In the above example the archive have to make sure that any values archived by
 * the callback (the delegate) get archived as an element of the array. The same
 * principle applies to objects, structs, associative arrays and other
 * non-primitives that accepts a delegate as a parameter.
 *
 * An archive implementation needs to be able to handle errors, like missing values
 * in the serialized data, without throwing exceptions. This is because the
 * interface of the serializer and an archive allows the user to set an error
 * callback that is called when an error occurs; and the callback can choose to
 * ignore the exceptions.
 *
 * In all the examples below "XmlArchive" is used as an example of an archive
 * implementation. "data" is assumed to be the serialized data.
 *
 * When implementing a new archive type, if any of these methods do not make sense
 * for that particular implementation just implement an empty method and return
 * T.init, if the method returns a value.
 */
interface Archiver
{
    mixin ArchiverMixin;

    /// Starts the archiving process. Call this method before archiving any values.
    void beginArchiving ();

    /// Returns the data stored in the archive in an untyped form.
    @property UntypedData untypedData ();

    /**
     * Resets the archive. This resets the archive in a state making it ready to start
     * a new archiving process.
     */
    void reset ();

    /**
     * Archives an array.
     *
     * Examples:
     * ---
     * int[] arr = [1, 2, 3];
     *
     * auto archive = new XmlArchive!();
     *
     * auto a = Array(arr.ptr, arr.length, typeof(a[0]).sizeof);
     *
     * archive.archive(a, typeof(a[0]).string, "arr", 0, {
     *     // archive the individual elements
     * });
     * ---
     *
     * Params:
     *     array = the array to archive
     *     type = the runtime type of an element of the array
     *     key = the key associated with the array
     *     id = the id associated with the array
     *     dg = a callback that performs the archiving of the individual elements
     */
    void beginArchiveArray (Array array, string type, string key, Id id);

    void endArchiveArray ();

    /**
     * Archives an associative array.
     *
     * Examples:
     * ---
     * int[string] arr = ["a"[] : 1, "b" : 2, "c" : 3];
     *
     * auto archive = new XmlArchive!();
     *
     * archive.archive(string.stringof, int.stringof, arr.length, "arr", 0, {
     *     // archive the individual keys and values
     * });
     * ---
     *
     *
     * Params:
     *     keyType = the runtime type of the keys
     *     valueType = the runtime type of the values
     *     length = the length of the associative array
     *     key = the key associated with the associative array
     *     id = the id associated with the associative array
     *     dg = a callback that performs the archiving of the individual keys and values
     *
     * See_Also: $(LREF archiveAssociativeArrayValue)
     * See_Also: $(LREF archiveAssociativeArrayKey)
     */
    void beginArchiveAssociativeArray (string keyType, string valueType, size_t length, string key, Id id);

    void endArchiveAssociativeArray ();

    /**
     * Archives an associative array key.
     *
     * There are separate methods for archiving associative array keys and values
     * because both the key and the value can be of arbitrary type and needs to be
     * archived on its own.
     *
     * Examples:
     * ---
     * int[string] arr = ["a"[] : 1, "b" : 2, "c" : 3];
     *
     * auto archive = new XmlArchive!();
     *
     * foreach(k, v ; arr)
     * {
     *     archive.archiveAssociativeArrayKey(to!(string)(i), {
     *         // archive the key
     *     });
     * }
     * ---
     *
     * The foreach statement in the above example would most likely be executed in the
     * callback passed to the archiveAssociativeArray method.
     *
     * Params:
     *     key = the key associated with the key
     *     dg = a callback that performs the actual archiving of the key
     *
     * See_Also: $(LREF archiveAssociativeArray)
     * See_Also: $(LREF archiveAssociativeArrayValue)
     */
    void beginArchiveAssociativeArrayKey (string key);

    void endArchiveAssociativeArrayKey ();

    /**
     * Archives an associative array value.
     *
     * There are separate methods for archiving associative array keys and values
     * because both the key and the value can be of arbitrary type and needs to be
     * archived on its own.
     *
     * Examples:
     * ---
     * int[string] arr = ["a"[] : 1, "b" : 2, "c" : 3];
     *
     * auto archive = new XmlArchive!();
     * size_t i;
     *
     * foreach(k, v ; arr)
     * {
     *     archive.archiveAssociativeArrayValue(to!(string)(i), {
     *         // archive the value
     *     });
     *
     *     i++;
     * }
     * ---
     *
     * The foreach statement in the above example would most likely be executed in the
     * callback passed to the archiveAssociativeArray method.
     *
     * Params:
     *     key = the key associated with the value
     *     dg = a callback that performs the actual archiving of the value
     *
     * See_Also: $(LREF archiveAssociativeArray)
     * See_Also: $(LREF archiveAssociativeArrayKey)
     */
    void beginArchiveAssociativeArrayValue (string key);

    void endArchiveAssociativeArrayValue ();

    /**
     * Archives the given value.
     *
     * Example:
     * ---
     * enum Foo : bool
     * {
     *     bar
     * }
     *
     * auto foo = Foo.bar;
     * auto archive = new XmlArchive!();
     * archive.archive(foo, "bool", "foo", 0);
     * ---
     *
     * Params:
     *     value = the value to archive
     *     baseType = the base type of the enum
     *     key = the key associated with the value
     *     id = the id associated with the value
     */
    void archiveEnum (bool value, string baseType, string key, Id id);

    /// Ditto
    void archiveEnum (byte value, string baseType, string key, Id id);

    /// Ditto
    void archiveEnum (char value, string baseType, string key, Id id);

    /// Ditto
    void archiveEnum (dchar value, string baseType, string key, Id id);

    /// Ditto
    void archiveEnum (int value, string baseType, string key, Id id);

    /// Ditto
    void archiveEnum (long value, string baseType, string key, Id id);

    /// Ditto
    void archiveEnum (short value, string baseType, string key, Id id);

    /// Ditto
    void archiveEnum (ubyte value, string baseType, string key, Id id);

    /// Ditto
    void archiveEnum (uint value, string baseType, string key, Id id);

    /// Ditto
    void archiveEnum (ulong value, string baseType, string key, Id id);

    /// Ditto
    void archiveEnum (ushort value, string baseType, string key, Id id);

    /// Ditto
    void archiveEnum (wchar value, string baseType, string key, Id id);

    /**
     * Archives a base class.
     *
     * This method is used to indicate that the all following calls to archive a value
     * should be part of the base class. This method is usually called within the
     * callback passed to $(LREF archiveObject). The $(LREF archiveObject)
     * method can the mark the end of the class.
     *
     * Examples:
     * ---
     * class ArchiveBase {}
     * class Foo : ArchiveBase {}
     *
     * auto archive = new XmlArchive!();
     * archive.archiveBaseClass("ArchiveBase", "base", 0);
     * ---
     *
     * Params:
     *     type = the type of the base class to archive
     *     key = the key associated with the base class
     *     id = the id associated with the base class
     *
     * See_Also: $(LREF archiveObject)
     */
    void archiveBaseClass (string type, string key, Id id);

    /**
     * Archives a null pointer or reference.
     *
     * Examples:
     * ---
     * int* ptr;
     *
     * auto archive = new XmlArchive!();
     * archive.archiveNull(typeof(ptr).stringof, "ptr");
     * ---
     *
     * Params:
     *     type = the runtime type of the pointer or reference to archive
     *     key = the key associated with the null pointer
     */
    void archiveNull (string type, string key);

    /**
     * Archives an object, either a class or an interface.
     *
     * Examples:
     * ---
     * class Foo
     * {
     *     int a;
     * }
     *
     * auto foo = new Foo;
     *
     * auto archive = new XmlArchive!();
     * archive.archiveObject(Foo.classinfo.name, "Foo", "foo", 0, {
     *     // archive the fields of Foo
     * });
     * ---
     *
     * Params:
     *     runtimeType = the runtime type of the object
     *     type = the static type of the object
     *     key = the key associated with the object
     *     id = the id associated with the object
     *     dg = a callback that performs the archiving of the individual fields
     *
     * See_Also: $(LREF archiveBaseClass)
     */
    void beginArchiveObject (string runtimeType, string type, string key, Id id);

    void endArchiveObject ();

    /**
     * Archives a pointer.
     *
     * If a pointer points to a value that is serialized as well, the pointer should be
     * archived as a reference. Otherwise the value that the pointer points to should be
     * serialized as a regular value.
     *
     * Examples:
     * ---
     * class Foo
     * {
     *     int a;
     *     int* b;
     * }
     *
     * auto foo = new Foo;
     * foo.a = 3;
     * foo.b = &foo.a;
     *
     * archive = new XmlArchive!();
     * archive.archivePointer("b", 0, {
     *     // archive "foo.b" as a reference
     * });
     * ---
     *
     * ---
     * int a = 3;
     *
     * class Foo
     * {
     *     int* b;
     * }
     *
     * auto foo = new Foo;
     * foo.b = &a;
     *
     * archive = new XmlArchive!();
     * archive.archivePointer("b", 0, {
     *     // archive "foo.b" as a regular value
     * });
     * ---
     *
     * Params:
     *     key = the key associated with the pointer
     *     id = the id associated with the pointer
     *     dg = a callback that performs the archiving of value pointed to by the pointer
     */
    void beginArchivePointer (string key, Id id);

    void endArchivePointer ();

    /**
     * Archives a reference.
     *
     * A reference is reference to another value. For example, if an object is archived
     * more than once, the first time it's archived it will actual archive the object.
     * The second time the object will be archived a reference will be archived instead
     * of the actual object.
     *
     * This method is also used when archiving a pointer that points to a value that has
     * been or will be archived as well.
     *
     * Examples:
     * ---
     * class Foo {}
     *
     * class Bar
     * {
     *     Foo f;
     *     Foo f2;
     * }
     *
     * auto bar = new Bar;
     * bar.f = new Foo;
     * bar.f2 = bar.f;
     *
     * auto archive = new XmlArchive!();
     *
     * // when achiving "bar"
     * archive.archiveObject(Foo.classinfo.name, "Foo", "f", 0, {});
     * archive.archiveReference("f2", 0); // archive a reference to "f"
     * ---
     *
     * Params:
     *     key = the key associated with the reference
     *     id = the id of the value this reference refers to
     */
    void archiveReference (string key, Id id);

    /**
     * Archives a slice.
     *
     * This method should be used when archiving an array that is a slice of an
     * already archived array or an array that has not yet been archived.
     *
     * Examples:
     * ---
     * auto arr = [1, 2, 3, 4];
     * auto slice = arr[1 .. 3];
     *
     * auto archive = new XmlArchive!();
     * // archive "arr" with id 0
     *
     * auto s = Slice(slice.length, 1);
     * archive.archiveSlice(s, 1, 0);
     * ---
     *
     * Params:
     *     slice = the slice to be archived
     *     sliceId = the id associated with the slice
     *     arrayId = the id associated with the array this slice is a slice of
     */
    void archiveSlice (Slice slice, Id sliceId, Id arrayId);

    /**
     * Archives a struct.
     *
     * Examples:
     * ---
     * struct Foo
     * {
     *     int a;
     * }
     *
     * auto foo = Foo(3);
     *
     * auto archive = new XmlArchive!();
     * archive.archiveStruct(Foo.stringof, "foo", 0, {
     *     // archive the fields of Foo
     * });
     * ---
     *
     * Params:
     *     type = the type of the struct
     *     key = the key associated with the struct
     *     id = the id associated with the struct
     *     dg = a callback that performs the archiving of the individual fields
     */
    void beginArchiveStruct (string type, string key, Id id);

    void endArchiveStruct ();

    /**
     * Archives a typedef.
     *
     * Examples:
     * ---
     * typedef int Foo;
     * Foo a = 3;
     *
     * auto archive = new XmlArchive!();
     * archive.archiveTypedef(Foo.stringof, "a", 0, {
     *     // archive "a" as the base type of Foo, i.e. int
     * });
     * ---
     *
     * Params:
     *     type = the type of the typedef
     *     key = the key associated with the typedef
     *     id = the id associated with the typedef
     *     dg = a callback that performs the archiving of the value as the base
     *             type of the typedef
     */
    void beginArchiveTypedef (string type, string key, Id id);

    void endArchiveTypedef ();

    /**
     * Archives the given value.
     *
     * Params:
     *     value = the value to archive
     *     key = the key associated with the value
     *     id = the id associated wit the value
     */
    void archive (string value, string key, Id id);

    /// Ditto
    void archive (wstring value, string key, Id id);

    /// Ditto
    void archive (dstring value, string key, Id id);

    ///    Ditto
    void archive (bool value, string key, Id id);

    /// Ditto
    void archive (byte value, string key, Id id);


    //void archive (cdouble value, string key, Id id); // currently not supported by to!()


    //void archive (cent value, string key, Id id);

    //void archive (cfloat value, string key, Id id); // currently not supported by to!()

    /// Ditto
    void archive (char value, string key, Id id);

    //void archive (creal value, string key, Id id); // currently not supported by to!()

    /// Ditto
    void archive (dchar value, string key, Id id);

    /// Ditto
    void archive (double value, string key, Id id);

    /// Ditto
    void archive (float value, string key, Id id);


    //void archive (idouble value, string key, Id id); // currently not supported by to!()

    //void archive (ifloat value, string key, Id id); // currently not supported by to!()

    /// Ditto
    void archive (int value, string key, Id id);


    //void archive (ireal value, string key, Id id); // currently not supported by to!()

    /// Ditto
    void archive (long value, string key, Id id);

    /// Ditto
    void archive (real value, string key, Id id);

    /// Ditto
    void archive (short value, string key, Id id);

    /// Ditto
    void archive (ubyte value, string key, Id id);

    //void archive (ucent value, string key, Id id); // currently not implemented but a reserved keyword

    /// Ditto
    void archive (uint value, string key, Id id);

    /// Ditto
    void archive (ulong value, string key, Id id);

    /// Ditto
    void archive (ushort value, string key, Id id);

    /// Ditto
    void archive (wchar value, string key, Id id);

    /**
     * Performs post processing of the array associated with the given id.
     *
     * Post processing can basically be anything that the archive wants to do. This
     * method is called by the serializer once for each serialized array at the end of
     * the serialization process when all values have been serialized.
     *
     * With this method the archive has a last chance of changing an archived array to
     * an archived slice instead.
     *
     * Params:
     *     id = the id associated with the array
     */
    void postProcessArray (Id id);

    /// Flushes the archiver and outputs its data to the internal output range.
    void flush ();
}

/**
 * This class serves as an optional base class for archive implementations. It
 * contains some utility methods that can be helpful when creating a new archive
 * implementation.
 *
 * Most of the examples below are assumed to be in a sub class to this class and
 * with $(I string) as the data type.
 */
abstract class ArchiverBase (DataType) : Archiver
{
    mixin ArchiverBaseMixin!(DataType);

    /**
     * The archive is responsible for archiving primitive types in the format chosen by
     * Converts the given floating point value to the type used for archiving.
     *
     * This method is used to convert floating point values, it will convert the
     * floating point value to hexadecimal format.
     *
     * Examples:
     * ---
     * auto f = floatingPointToData(3.15f);
     * assert(f == "0xc.9999ap-2");
     * ---
     *
     * Params:
     *     value = the value to convert
     *
     * Returns: the conveted value
     *
     * Throws: SerializationException if the conversion failed
     */
    protected Data floatingPointToData (T) (T value)
    {
        static assert(isFloatingPoint!(T), format!(`The given value of the type "`, T,
            `" is not a valid type, the only valid types for this method are floating point types.`));

        return to!(Data)(std.string.format("%a", value));
    }

    /**
     * Calls the errorCallback with an exception.
     *
     * Call this method when some type of error occurred, like a field cannot be found.
     *
     * Params:
     *     message = the message for the exception
     *     file = the file where the error occurred
     *     line = the line where the error occurred
     */
    protected void error (string message, string[] data = null, string file = __FILE__, size_t line = __LINE__)
    {
        if (errorCallback)
            errorCallback()(new SerializationException(message, file, line));
    }

    /**
     * Calls the errorCallback with an exception.
     *
     * Call this method when some type of error occurred, like a field cannot be found.
     *
     * Params:
     *     exception = the exception to pass to the errorCallback
     */
    protected void error (Exception exception)
    {
        if (errorCallback)
            errorCallback()(new SerializationException(exception));
    }
}