/**
 * Copyright: Copyright (c) 2013 Jacob Carlborg.
 * Authors: Jacob Carlborg
 * Version: Initial created: Sep 6, 2010
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 *
 * Source: $(PHOBOSSRC std/serialization/archivers/_unarchive.d)
 */
module std.serialization.archivers.unarchiver;

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
interface Unarchiver
{
    mixin ArchiverMixin;

    /**
     * Begins the unarchiving process. Call this method before unarchiving any values.
     *
     * Params:
     *     data = the data to unarchive
     */
    void beginUnarchiving (UntypedData data);

    /// Returns the data stored in the archive in an untyped form.
    @property UntypedData untypedData ();

    /**
     * Resets the archive. This resets the archive in a state making it ready to start
     * a new archiving process.
     */
    void reset ();

    /**
     * Unarchives the value associated with the given key as an array.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     * auto id = archive.unarchiveArray("arr", (size_t length) {
     *     auto arr = new int[length]; // pre-allocate the array
     *     // unarchive the individual elements of "arr"
     * });
     * ---
     *
     * Params:
     *     key = the key associated with the array
     *     dg = a callback that performs the unarchiving of the individual elements.
     *             $(I length) is the length of the archived array
     *
     * Returns: the id associated with the array
     *
     * See_Also: $(LREF unarchiveArray)
     */
    Id unarchiveArray (string key, void delegate (size_t length) dg);

    /**
     * Unarchives the value associated with the given id as an array.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     * archive.unarchiveArray(0, (size_t length) {
     *     auto arr = new int[length]; // pre-allocate the array
     *     // unarchive the individual elements of "arr"
     * });
     * ---
     *
     * Params:
     *     id = the id associated with the value
     *     dg = a callback that performs the unarchiving of the individual elements.
     *             $(I length) is the length of the archived array
     *
     * See_Also: $(LREF unarchiveArray)
     */
    void unarchiveArray (Id id, void delegate (size_t length) dg);

    /**
     * Unarchives the value associated with the given id as an associative array.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     *
     * auto id = archive.unarchiveAssociativeArray("aa", (size_t length) {
     *     // unarchive the individual keys and values
     * });
     * ---
     *
     * Params:
     *     key = the key associated with the associative array
     *     dg = a callback that performs the unarchiving of the individual keys and values.
     *             $(I length) is the length of the archived associative array
     *
     * Returns: the id associated with the associative array
     *
     * See_Also: $(LREF unarchiveAssociativeArrayKey)
     * See_Also: $(LREF unarchiveAssociativeArrayValue)
     */
    Id unarchiveAssociativeArray (string key, void delegate (size_t length) dg);

    /**
     * Unarchives an associative array key.
     *
     * There are separate methods for unarchiving associative array keys and values
     * because both the key and the value can be of arbitrary type and needs to be
     * unarchived on its own.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     *
     * for (size_t i = 0; i < length; i++)
     * {
     *     unarchiveAssociativeArrayKey(to!(string(i), {
     *         // unarchive the key
     *     });
     * }
     * ---
     *
     * The for statement in the above example would most likely be executed in the
     * callback passed to the unarchiveAssociativeArray method.
     *
     * Params:
     *     key = the key associated with the key
     *     dg = a callback that performs the actual unarchiving of the key
     *
     * See_Also: $(LREF unarchiveAssociativeArrayValue)
     * See_Also: $(LREF unarchiveAssociativeArray)
     */
    void unarchiveAssociativeArrayKey (string key, void delegate () dg);

    /**
     * Unarchives an associative array value.
     *
     * There are separate methods for unarchiving associative array keys and values
     * because both the key and the value can be of arbitrary type and needs to be
     * unarchived on its own.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     *
     * for (size_t i = 0; i < length; i++)
     * {
     *     unarchiveAssociativeArrayValue(to!(string(i), {
     *         // unarchive the value
     *     });
     * }
     * ---
     *
     * The for statement in the above example would most likely be executed in the
     * callback passed to the unarchiveAssociativeArray method.
     *
     * Params:
     *     key = the key associated with the value
     *     dg = a callback that performs the actual unarchiving of the value
     *
     * See_Also: $LREF(unarchiveAssociativeArrayKey)
     * See_Also: $LREF(unarchiveAssociativeArray)
     */
    void unarchiveAssociativeArrayValue (string key, void delegate () dg);

    /**
     * Unarchives the value associated with the given key as a bool.
     *
     * This method is used when the unarchiving a enum value with the base type bool.
     *
     * Params:
     *     key = the key associated with the value
     *
     * Returns: the unarchived value
     */
    bool unarchiveEnumBool (string key);

    /// Ditto
    byte unarchiveEnumByte (string key);

    /// Ditto
    char unarchiveEnumChar (string key);

    /// Ditto
    dchar unarchiveEnumDchar (string key);

    /// Ditto
    int unarchiveEnumInt (string key);

    /// Ditto
    long unarchiveEnumLong (string key);

    /// Ditto
    short unarchiveEnumShort (string key);

    /// Ditto
    ubyte unarchiveEnumUbyte (string key);

    /// Ditto
    uint unarchiveEnumUint (string key);

    /// Ditto
    ulong unarchiveEnumUlong (string key);

    /// Ditto
    ushort unarchiveEnumUshort (string key);

    /// Ditto
    wchar unarchiveEnumWchar (string key);

    /**
     * Unarchives the value associated with the given id as a bool.
     *
     * This method is used when the unarchiving a enum value with the base type bool.
     *
     * Params:
     *     id = the id associated with the value
     *
     * Returns: the unarchived value
     */
    bool unarchiveEnumBool (Id id);

    /// Ditto
    byte unarchiveEnumByte (Id id);

    /// Ditto
    char unarchiveEnumChar (Id id);

    /// Ditto
    dchar unarchiveEnumDchar (Id id);

    /// Ditto
    int unarchiveEnumInt (Id id);

    /// Ditto
    long unarchiveEnumLong (Id id);

    /// Ditto
    short unarchiveEnumShort (Id id);

    /// Ditto
    ubyte unarchiveEnumUbyte (Id id);

    /// Ditto
    uint unarchiveEnumUint (Id id);

    /// Ditto
    ulong unarchiveEnumUlong (Id id);

    /// Ditto
    ushort unarchiveEnumUshort (Id id);

    /// Ditto
    wchar unarchiveEnumWchar (Id id);

    /**
     * Unarchives the base class associated with the given key.
     *
     * This method is used to indicate that the all following calls to unarchive a
     * value should be part of the base class. This method is usually called within the
     * callback passed to unarchiveObject. The unarchiveObject method can the mark the
     * end of the class.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     * archive.unarchiveBaseClass("base");
     * ---
     *
     * Params:
     *     key = the key associated with the base class.
     *
     * See_Also: $(LREF unarchiveObject)
     */
    void unarchiveBaseClass (string key);

    /**
     * Unarchives the object associated with the given key.
     *
     * Examples:
     * ---
     * class Foo
     * {
     *     int a;
     * }
     *
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     *
     * Id id;
     * Object o;
     *
     * archive.unarchiveObject("foo", id, o, {
     *     // unarchive the fields of Foo
     * });
     *
     * auto foo = cast(Foo) o;
     * ---
     *
     * Params:
     *     key = the key associated with the object
     *     id = the id associated with the object
     *     result = the unarchived object
     *     dg = a callback the performs the unarchiving of the individual fields
     *
     * See_Also: $(unarchiveBaseClass)
     */
    void unarchiveObject (string key, out Id id, out Object result, void delegate () dg);

    /**
     * Unarchives the pointer associated with the given key.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     * auto id = unarchivePointer("ptr", {
     *     // unarchive the value pointed to by the pointer
     * });
     * ---
     *
     * Params:
     *     key = the key associated with the pointer
     *     dg = a callback that performs the unarchiving of value pointed to by the pointer
     *
     * Returns: the id associated with the pointer
     */
    Id unarchivePointer (string key, void delegate () dg);

    /**
     * Unarchives the reference associated with the given key.
     *
     * A reference is reference to another value. For example, if an object is archived
     * more than once, the first time it's archived it will actual archive the object.
     * The second time the object will be archived a reference will be archived instead
     * of the actual object.
     *
     * This method is also used when unarchiving a pointer that points to a value that has
     * been or will be unarchived as well.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     * auto id = unarchiveReference("foo");
     *
     * // unarchive the value with the associated id
     * ---
     *
     * Params:
     *     key = the key associated with the reference
     *
     * Returns: the id the reference refers to
     */
    Id unarchiveReference (string key);

    /**
     * Unarchives the slice associated with the given key.
     *
     * This method should be used when unarchiving an array that is a slice of an
     * already unarchived array or an array that has not yet been unarchived.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     * auto slice = unarchiveSlice("slice");
     *
     * // slice the original array with the help of the unarchived slice
     * ---
     *
     * Params:
     *     key = the key associated with the slice
     *
     * Returns: the unarchived slice
     */
    Slice unarchiveSlice (string key);

    /**
     * Unarchives the struct associated with the given key.
     *
     * Examples:
     * ---
     * struct Foo
     * {
     *     int a;
     * }
     *
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     * archive.unarchiveStruct("foo", {
     *     // unarchive the fields of Foo
     * });
     * ---
     *
     * Params:
     *     key = the key associated with the string
     *     dg = a callback that performs the unarchiving of the individual fields
     */
    void unarchiveStruct (string key, void delegate () dg);

    /**
     * Unarchives the struct associated with the given id.
     *
     * Examples:
     * ---
     * struct Foo
     * {
     *     int a;
     * }
     *
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     * archive.unarchiveStruct(0, {
     *     // unarchive the fields of Foo
     * });
     * ---
     *
     * Params:
     *     id = the id associated with the struct
     *     dg = a callback that performs the unarchiving of the individual fields.
     *                The callback will receive the key the struct was archived with.
     */
    void unarchiveStruct (Id id, void delegate () dg);

    /**
     * Unarchives the typedef associated with the given key.
     *
     * Examples:
     * ---
     * typedef int Foo;
     * Foo foo = 3;
     *
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     * archive.unarchiveTypedef("foo", {
     *     // unarchive "foo" as the base type of Foo, i.e. int
     * });
     * ---
     *
     * Params:
     *     key = the key associated with the typedef
     *     dg = a callback that performs the unarchiving of the value as
     *              the base type of the typedef
     */
    void unarchiveTypedef (string key, void delegate () dg);

    /**
     * Unarchives the string associated with the given id.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     * auto str = archive.unarchiveString(0);
     * ---
     *
     * Params:
     *     id = the id associated with the string
     *
     * Returns: the unarchived string
     */
    string unarchiveString (Id id);

    /// Ditto
    wstring unarchiveWstring (Id id);

    /// Ditto
    dstring unarchiveDstring (Id id);

    /**
     * Unarchives the string associated with the given key.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     *
     * Id id;
     * auto str = archive.unarchiveString("str", id);
     * ---
     *
     * Params:
     *     id = the id associated with the string
     *
     * Returns: the unarchived string
     */
    string unarchiveString (string key, out Id id);

    /// Ditto
    wstring unarchiveWstring (string key, out Id id);

    /// Ditto
    dstring unarchiveDstring (string key, out Id id);

    /**
     * Unarchives the value associated with the given key.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     * auto foo = unarchiveBool("foo");
     * ---
     * Params:
     *     key = the key associated with the value
     *
     * Returns: the unarchived value
     */
    bool unarchiveBool (string key);

    /// Ditto
    byte unarchiveByte (string key);

    //cdouble unarchiveCdouble (string key); // currently not supported by to!()
    //cent unarchiveCent (string key); // currently not implemented but a reserved keyword
    //cfloat unarchiveCfloat (string key); // currently not supported by to!()

    /// Ditto
    char unarchiveChar (string key); // currently not implemented but a reserved keyword
    //creal unarchiveCreal (string key); // currently not supported by to!()

    /// Ditto
    dchar unarchiveDchar (string key);

    /// Ditto
    double unarchiveDouble (string key);

    /// Ditto
    float unarchiveFloat (string key);
    //idouble unarchiveIdouble (string key); // currently not supported by to!()
    //ifloat unarchiveIfloat (string key); // currently not supported by to!()*/

    /// Ditto
    int unarchiveInt (string key);

    //ireal unarchiveIreal (string key); // currently not supported by to!()

    /// Ditto
    long unarchiveLong (string key);

    /// Ditto
    real unarchiveReal (string key);

    /// Ditto
    short unarchiveShort (string key);

    /// Ditto
    ubyte unarchiveUbyte (string key);

    ///
    //ucent unarchiveCcent (string key); // currently not implemented but a reserved keyword

    /// Ditto
    uint unarchiveUint (string key);

    /// Ditto
    ulong unarchiveUlong (string key);

    /// Ditto
    ushort unarchiveUshort (string key);

    /// Ditto
    wchar unarchiveWchar (string key);

    /**
     * Unarchives the value associated with the given id.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * archive.beginUnarchiving(data);
     * auto foo = unarchiveBool(0);
     * ---
     * Params:
     *     id = the id associated with the value
     *
     * Returns: the unarchived value
     */
    bool unarchiveBool (Id id);

    /// Ditto
    byte unarchiveByte (Id id);

    //cdouble unarchiveCdouble (Id id); // currently not supported by to!()
    //cent unarchiveCent (Id id); // currently not implemented but a reserved keyword
    //cfloat unarchiveCfloat (Id id); // currently not supported by to!()

    /// Ditto
    char unarchiveChar (Id id); // currently not implemented but a reserved keyword
    //creal unarchiveCreal (Id id); // currently not supported by to!()

    /// Ditto
    dchar unarchiveDchar (Id id);

    /// Ditto
    double unarchiveDouble (Id id);

    /// Ditto
    float unarchiveFloat (Id id);
    //idouble unarchiveIdouble (Id id); // currently not supported by to!()
    //ifloat unarchiveIfloat (Id id); // currently not supported by to!()*/

    /// Ditto
    int unarchiveInt (Id id);

    //ireal unarchiveIreal (Id id); // currently not supported by to!()

    /// Ditto
    long unarchiveLong (Id id);

    /// Ditto
    real unarchiveReal (Id id);

    /// Ditto
    short unarchiveShort (Id id);

    /// Ditto
    ubyte unarchiveUbyte (Id id);

    ///
    //ucent unarchiveCcent (Id id); // currently not implemented but a reserved keyword

    /// Ditto
    uint unarchiveUint (Id id);

    /// Ditto
    ulong unarchiveUlong (Id id);

    /// Ditto
    ushort unarchiveUshort (Id id);

    /// Ditto
    wchar unarchiveWchar (Id id);
}

/**
 * This class serves as an optional base class for archive implementations. It
 * contains some utility methods that can be helpful when creating a new archive
 * implementation.
 *
 * Most of the examples below are assumed to be in a sub class to this class and
 * with $(I string) as the data type.
 */
abstract class UnarchiverBase (DataType) : Unarchiver
{
    mixin ArchiverBaseMixin!(DataType);

    /**
     * Converts the given value from the type used for archiving to $(I T).
     *
     * Examples:
     * ---
     * auto i = fromData!(int)("3");
     * assert(i == 3);
     * ---
     *
     * Params:
     *        T = the type to convert the given value to
     *     value = the value to convert
     *
     * Returns: the converted value
     *
     * Throws: SerializationException if the conversion failed
     * See_Also: $(LREF toData)
     */
    protected T fromData (T) (Data value)
    {
        try
        {
            static if (is(T == wchar))
                return toWchar(value);

            else
                return to!(T)(value);
        }

        catch (ConvException e)
        {
            error(e);
            return T.init;
        }
    }

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
     * Converts the id value to the type $(I Id).
     *
     * This method is used to conver ids stored in the serialized data to the correct
     * type.
     *
     * Params:
     *     value = the value to convert
     *
     * Returns: the converted id
     *
     * Throws: SerializationException if the converted failed
     * See_Also: $(LREF fromData)
     */
    protected Id toId (Data value)
    {
        return fromData!(Id)(value);
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

    private wchar toWchar (Data value)
    {
        auto c = value.front;

        if (codeLength!(wchar)(c) > 2)
            throw new ConvException("Could not convert `" ~
                to!(string)(value) ~ "` of type " ~
                Data.stringof ~ " to type wchar.");

        return cast(wchar) c;
    }
}

private
{
    version (LDC)
        extern (C) Object _d_allocclass(in ClassInfo);

    else
        extern (C) Object _d_newclass(in ClassInfo);
}

package:

/**
 * Returns a new instnace of the class associated with the given class info.
 *
 * Params:
 *     classInfo = the class info associated with the class
 *
 * Returns: a new instnace of the class associated with the given class info.
 */
Object newInstance (in ClassInfo classInfo)
{
    version (LDC)
    {
        Object object = _d_allocclass(classInfo);
        (cast(byte*) object)[0 .. classInfo.init.length] = classInfo.init[];

        return object;
    }

    else
        return _d_newclass(classInfo);
}

/**
 * Return a new instance of the class with the given name.
 *
 * Params:
 *     name = the fully qualified name of the class
 *
 * Returns: a new instance or null if the class name could not be found
 */
Object newInstance (string name)
{
    auto classInfo = ClassInfo.find(name);

    if (!classInfo)
        return null;

    return newInstance(classInfo);
}