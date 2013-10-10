/**
 * Copyright: Copyright (c) 2010-2013 Jacob Carlborg.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 26, 2010
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 *
 * Source: $(PHOBOSSRC std/serialization/archivers/_xmlunarchiver.d)
 */
module std.serialization.archivers.xmlunarchiver;

import std.conv;
import std.serialization.archivers.unarchiver;
import std.serialization.archivers.xmlarchivermixin;
import std.serialization.archivers.xmldocument;
import std.serialization.serializer;
import std.serialization.serializermixin;
import std.traits;

/**
 * This class is a concrete implementation of the Archive interface. This archive
 * uses XML as the final format for the serialized data.
 */
final class XmlUnarchiver (U) : UnarchiverBase!(string)
{
    mixin XmlArchiverMixin;

    private
    {
        Data archiveType = "std.xml";
        Data archiveVersion = "1.0.0";

        XmlDocument doc;
        doc.Node lastElement;

        bool hasBegunUnarchiving;

        void[][Data] unarchivedSlices;
    }

    /**
     * Creates a new instance of this class with the give error callback.
     *
     * Params:
     *     errorCallback = The callback to be called when an error occurs
     */
    this (ErrorCallback errorCallback = null)
    {
        super(errorCallback);
        doc = new XmlDocument;
    }

    /**
     * Begins the unarchiving process. Call this method before unarchiving any values.
     *
     * Params:
     *     untypedData = the data to unarchive
     */
    public void beginUnarchiving (UntypedData untypedData)
    {
        auto data = cast(Data) untypedData;

        if (!hasBegunUnarchiving)
        {
            doc.parse(data);
            hasBegunUnarchiving = true;

            auto set = doc.query()[Tags.archiveTag][Tags.dataTag];

            if (set.nodes.length == 1)
                lastElement = set.nodes[0];

            else
            {
                auto dataTag = to!(string)(Tags.dataTag);

                if (set.nodes.length == 0)
                    error(errorMessage ~ `The "` ~ to!(string)(Tags.dataTag) ~ `" tag could not be found.`, [dataTag]);

                else
                    error(errorMessage ~ `There were more than one "` ~ to!(string)(Tags.dataTag) ~ `" tag.`, [dataTag]);
            }
        }
    }

    /// Returns the data stored in the archive in an untyped form.
    @property UntypedData untypedData ()
    {
        return doc.toString();
    }

    /// Returns the data stored in the archive in an typed form.
    @property Data data ()
    {
        return doc.toString();
    }

    /**
     * Resets the archive. This resets the archive in a state making it ready to start
     * a new archiving process.
     */
    void reset ()
    {
        hasBegunUnarchiving = false;
        doc.reset();
    }

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
    Id unarchiveArray (string key, void delegate (size_t) dg)
    {
        return restore!(lastElement, {
            auto element = getElement(Tags.arrayTag, key);

            if (!element.isValid)
                return Id.max;

            lastElement = element;
            auto len = getValueOfAttribute(Attributes.lengthAttribute);

            if (!len)
                return Id.max;

            auto length = fromData!(size_t)(len);
            auto id = getValueOfAttribute(Attributes.idAttribute);

            if (!id)
                return Id.max;

            dg(length);

            return toId(id);
        });
    }

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
    void unarchiveArray (Id id, void delegate (size_t) dg)
    {
        restore!(lastElement, {
            auto element = getElement(Tags.arrayTag, to!(string)(id), Attributes.idAttribute);

            if (!element.isValid)
                return;

            lastElement = element;
            auto len = getValueOfAttribute(Attributes.lengthAttribute);

            if (!len)
                return;

            auto length = fromData!(size_t)(len);
            auto stringId = getValueOfAttribute(Attributes.idAttribute);

            if (!stringId)
                return;

            dg(length);
        });
    }

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
    Id unarchiveAssociativeArray (string key, void delegate (size_t length) dg)
    {
        return restore!(lastElement, {
            auto element = getElement(Tags.associativeArrayTag, key);

            if (!element.isValid)
                return Id.max;

            lastElement = element;
            auto len = getValueOfAttribute(Attributes.lengthAttribute);

            if (!len)
                return Id.max;

            auto length = fromData!(size_t)(len);
            auto id = getValueOfAttribute(Attributes.idAttribute);

            if (!id)
                return Id.max;

            dg(length);

            return toId(id);
        });
    }

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
    void unarchiveAssociativeArrayKey (string key, void delegate () dg)
    {
        internalUnarchiveAAKeyValue(key, Tags.keyTag, dg);
    }

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
     * See_Also: $(LREF unarchiveAssociativeArrayKey)
     * See_Also: $(LREF unarchiveAssociativeArray)
     */
    void unarchiveAssociativeArrayValue (string key, void delegate () dg)
    {
        internalUnarchiveAAKeyValue(key, Tags.valueTag, dg);
    }

    private void internalUnarchiveAAKeyValue (string key, Data tag, void delegate () dg)
    {
        restore!(lastElement, {
            auto element = getElement(tag, key);

            if (!element.isValid)
                return;

            lastElement = element;

            dg();
        });
    }

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
    bool unarchiveEnumBool (string key)
    {
        return unarchiveEnum!(bool)(key);
    }

    /// Ditto
    byte unarchiveEnumByte (string key)
    {
        return unarchiveEnum!(byte)(key);
    }

    /// Ditto
    char unarchiveEnumChar (string key)
    {
        return unarchiveEnum!(char)(key);
    }

    /// Ditto
    dchar unarchiveEnumDchar (string key)
    {
        return unarchiveEnum!(dchar)(key);
    }

    /// Ditto
    int unarchiveEnumInt (string key)
    {
        return unarchiveEnum!(int)(key);
    }

    /// Ditto
    long unarchiveEnumLong (string key)
    {
        return unarchiveEnum!(long)(key);
    }

    /// Ditto
    short unarchiveEnumShort (string key)
    {
        return unarchiveEnum!(short)(key);
    }

    /// Ditto
    ubyte unarchiveEnumUbyte (string key)
    {
        return unarchiveEnum!(ubyte)(key);
    }

    /// Ditto
    uint unarchiveEnumUint (string key)
    {
        return unarchiveEnum!(uint)(key);
    }

    /// Ditto
    ulong unarchiveEnumUlong (string key)
    {
        return unarchiveEnum!(ulong)(key);
    }

    /// Ditto
    ushort unarchiveEnumUshort (string key)
    {
        return unarchiveEnum!(ushort)(key);
    }

    /// Ditto
    wchar unarchiveEnumWchar (string key)
    {
        return unarchiveEnum!(wchar)(key);
    }

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
    bool unarchiveEnumBool (Id id)
    {
        return unarchiveEnum!(bool)(id);
    }

    /// Ditto
    byte unarchiveEnumByte (Id id)
    {
        return unarchiveEnum!(byte)(id);
    }

    /// Ditto
    char unarchiveEnumChar (Id id)
    {
        return unarchiveEnum!(char)(id);
    }

    /// Ditto
    dchar unarchiveEnumDchar (Id id)
    {
        return unarchiveEnum!(dchar)(id);
    }

    /// Ditto
    int unarchiveEnumInt (Id id)
    {
        return unarchiveEnum!(int)(id);
    }

    /// Ditto
    long unarchiveEnumLong (Id id)
    {
        return unarchiveEnum!(long)(id);
    }

    /// Ditto
    short unarchiveEnumShort (Id id)
    {
        return unarchiveEnum!(short)(id);
    }

    /// Ditto
    ubyte unarchiveEnumUbyte (Id id)
    {
        return unarchiveEnum!(ubyte)(id);
    }

    /// Ditto
    uint unarchiveEnumUint (Id id)
    {
        return unarchiveEnum!(uint)(id);
    }

    /// Ditto
    ulong unarchiveEnumUlong (Id id)
    {
        return unarchiveEnum!(ulong)(id);
    }

    /// Ditto
    ushort unarchiveEnumUshort (Id id)
    {
        return unarchiveEnum!(ushort)(id);
    }

    /// Ditto
    wchar unarchiveEnumWchar (Id id)
    {
        return unarchiveEnum!(wchar)(id);
    }

    private T unarchiveEnum (T, U) (U keyOrId)
    {
        auto tag = Tags.enumTag;

        static if (isSomeString!(U))
            auto element = getElement(Tags.enumTag, keyOrId);

        else static if (is(U == Id))
            auto element = getElement(tag, toData(keyOrId), Attributes.idAttribute);

        else
            static assert (false, format!(`Invalid type "`, U, `". Valid types are "string" and "Id"`));

        if (!element.isValid)
            return T.init;

        return fromData!(T)(element.value);
    }

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
    void unarchiveBaseClass (string key)
    {
        auto element = getElement(Tags.baseTag, key);

        if (element.isValid)
            lastElement = element;
    }

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
     */
    void unarchiveObject (string key, out Id id, out Object result, void delegate () dg)
    {
        restore!(lastElement, {
            auto tmp = getElement(Tags.objectTag, key, Attributes.keyAttribute, false);

            if (!tmp.isValid)
            {
                lastElement = getElement(Tags.nullTag, key);
                return;
            }

            lastElement = tmp;

            auto runtimeType = getValueOfAttribute(Attributes.runtimeTypeAttribute);

            if (!runtimeType)
                return;

            auto name = fromData!(string)(runtimeType);
            auto stringId = getValueOfAttribute(Attributes.idAttribute);

            if (!stringId)
                return;

            id = toId(stringId);
            result = newInstance(name);
            dg();
        });
    }

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
    Id unarchivePointer (string key, void delegate () dg)
    {
        return restore!(lastElement, {
            auto tmp = getElement(Tags.pointerTag, key, Attributes.keyAttribute, false);

            if (!tmp.isValid)
            {
                lastElement = getElement(Tags.nullTag, key);
                return Id.max;
            }

            lastElement = tmp;
            auto id = getValueOfAttribute(Attributes.idAttribute);

            if (!id)
                return Id.max;

            dg();

            return toId(id);
        });
    }

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
    Id unarchiveReference (string key)
    {
        auto element = getElement(Tags.referenceTag, key, Attributes.keyAttribute, false);

        if (element.isValid)
            return toId(element.value);

        return Id.max;
    }

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
    Slice unarchiveSlice (string key)
    {
        auto element = getElement(Tags.sliceTag, key, Attributes.keyAttribute, false);

        if (element.isValid)
        {
            auto length = fromData!(size_t)(getValueOfAttribute(Attributes.lengthAttribute, element));
            auto offset = fromData!(size_t)(getValueOfAttribute(Attributes.offsetAttribute, element));
            auto id = toId(element.value);

            return Slice(length, offset, id);
        }

        return Slice.init;
    }

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
     *     key = the key associated with the struct
     *     dg = a callback that performs the unarchiving of the individual fields
     */
    void unarchiveStruct (string key, void delegate () dg)
    {
        restore!(lastElement, {
            auto element = getElement(Tags.structTag, key);

            if (!element.isValid)
                return;

            lastElement = element;
            dg();
        });
    }

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
    void unarchiveStruct (Id id, void delegate () dg)
    {
        restore!(lastElement, {
            auto element = getElement(Tags.structTag, toData(id), Attributes.idAttribute);

            if (!element.isValid)
                return;

            lastElement = element;
            dg();
        });
    }

    private T unarchiveTypeDef (T) (DataType key)
    {
        auto element = getElement(Tags.typedefTag, key);

        if (element.isValid)
            lastElement = element;

        return T.init;
    }

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
    void unarchiveTypedef (string key, void delegate () dg)
    {
        restore!(lastElement, {
            auto element = getElement(Tags.typedefTag, key);

            if (!element.isValid)
                return;

            lastElement = element;
            dg();
        });
    }

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
    string unarchiveString (string key, out Id id)
    {
        return internalUnarchiveString!(string)(key, id);
    }

    /// Ditto
    wstring unarchiveWstring (string key, out Id id)
    {
        return internalUnarchiveString!(wstring)(key, id);
    }

    /// Ditto
    dstring unarchiveDstring (string key, out Id id)
    {
        return internalUnarchiveString!(dstring)(key, id);
    }

    private T internalUnarchiveString (T) (string key, out Id id)
    {
        auto element = getElement(Tags.stringTag, key);

        if (!element.isValid)
            return T.init;

        auto value = fromData!(T)(element.value);
        auto stringId = getValueOfAttribute(Attributes.idAttribute, element);

        if (!stringId)
            return T.init;

        id = toId(stringId);
        return value;
    }

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
    string unarchiveString (Id id)
    {
        return internalUnarchiveString!(string)(id);
    }

    /// Ditto
    wstring unarchiveWstring (Id id)
    {
        return internalUnarchiveString!(wstring)(id);
    }

    /// Ditto
    dstring unarchiveDstring (Id id)
    {
        return internalUnarchiveString!(dstring)(id);
    }

    private T internalUnarchiveString (T) (Id id)
    {
        auto element = getElement(Tags.stringTag, to!(string)(id), Attributes.idAttribute);

        if (!element.isValid)
            return T.init;

        return fromData!(T)(element.value);
    }

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
    bool unarchiveBool (string key)
    {
        return unarchivePrimitive!(bool)(key);
    }

    /// Ditto
    byte unarchiveByte (string key)
    {
        return unarchivePrimitive!(byte)(key);
    }

    //currently not suppported by to!()
    /*cdouble unarchiveCdouble (string key)
    {
        return unarchivePrimitive!(cdouble)(key);
    }*/

     //currently not implemented but a reserved keyword
    /*cent unarchiveCent (string key)
    {
        return unarchivePrimitive!(cent)(key);
    }*/

    // currently not suppported by to!()
    /*cfloat unarchiveCfloat (string key)
    {
        return unarchivePrimitive!(cfloat)(key);
    }*/

    /// Ditto
    char unarchiveChar (string key)
    {
        return unarchivePrimitive!(char)(key);
    }

     //currently not implemented but a reserved keyword
    /*creal unarchiveCreal (string key)
    {
        return unarchivePrimitive!(creal)(key);
    }*/

    /// Ditto
    dchar unarchiveDchar (string key)
    {
        return unarchivePrimitive!(dchar)(key);
    }

    /// Ditto
    double unarchiveDouble (string key)
    {
        return unarchivePrimitive!(double)(key);
    }

    /// Ditto
    float unarchiveFloat (string key)
    {
        return unarchivePrimitive!(float)(key);
    }

    //currently not suppported by to!()
    /*idouble unarchiveIdouble (string key)
    {
        return unarchivePrimitive!(idouble)(key);
    }*/

    // currently not suppported by to!()*/
    /*ifloat unarchiveIfloat (string key)
    {
        return unarchivePrimitive!(ifloat)(key);
    }*/

    /// Ditto
    int unarchiveInt (string key)
    {
        return unarchivePrimitive!(int)(key);
    }

    // currently not suppported by to!()
    /*ireal unarchiveIreal (string key)
    {
        return unarchivePrimitive!(ireal)(key);
    }*/

    /// Ditto
    long unarchiveLong (string key)
    {
        return unarchivePrimitive!(long)(key);
    }

    /// Ditto
    real unarchiveReal (string key)
    {
        return unarchivePrimitive!(real)(key);
    }

    /// Ditto
    short unarchiveShort (string key)
    {
        return unarchivePrimitive!(short)(key);
    }

    /// Ditto
    ubyte unarchiveUbyte (string key)
    {
        return unarchivePrimitive!(ubyte)(key);
    }

    // currently not implemented but a reserved keyword
    /*ucent unarchiveCcent (string key)
    {
        return unarchivePrimitive!(ucent)(key);
    }*/

    /// Ditto
    uint unarchiveUint (string key)
    {
        return unarchivePrimitive!(uint)(key);
    }

    /// Ditto
    ulong unarchiveUlong (string key)
    {
        return unarchivePrimitive!(ulong)(key);
    }

    /// Ditto
    ushort unarchiveUshort (string key)
    {
        return unarchivePrimitive!(ushort)(key);
    }

    /// Ditto
    wchar unarchiveWchar (string key)
    {
        return unarchivePrimitive!(wchar)(key);
    }

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
    bool unarchiveBool (Id id)
    {
        return unarchivePrimitive!(bool)(id);
    }

    /// Ditto
    byte unarchiveByte (Id id)
    {
        return unarchivePrimitive!(byte)(id);
    }

    //currently not suppported by to!()
    /*cdouble unarchiveCdouble (Id id)
    {
        return unarchivePrimitive!(cdouble)(id);
    }*/

     //currently not implemented but a reserved keyword
    /*cent unarchiveCent (Id id)
    {
        return unarchivePrimitive!(cent)(id);
    }*/

    // currently not suppported by to!()
    /*cfloat unarchiveCfloat (Id id)
    {
        return unarchivePrimitive!(cfloat)(id);
    }*/

    /// Ditto
    char unarchiveChar (Id id)
    {
        return unarchivePrimitive!(char)(id);
    }

     //currently not implemented but a reserved keyword
    /*creal unarchiveCreal (Id id)
    {
        return unarchivePrimitive!(creal)(id);
    }*/

    /// Ditto
    dchar unarchiveDchar (Id id)
    {
        return unarchivePrimitive!(dchar)(id);
    }

    /// Ditto
    double unarchiveDouble (Id id)
    {
        return unarchivePrimitive!(double)(id);
    }

    /// Ditto
    float unarchiveFloat (Id id)
    {
        return unarchivePrimitive!(float)(id);
    }

    //currently not suppported by to!()
    /*idouble unarchiveIdouble (Id id)
    {
        return unarchivePrimitive!(idouble)(id);
    }*/

    // currently not suppported by to!()*/
    /*ifloat unarchiveIfloat (Id id)
    {
        return unarchivePrimitive!(ifloat)(id);
    }*/

    /// Ditto
    int unarchiveInt (Id id)
    {
        return unarchivePrimitive!(int)(id);
    }

    // currently not suppported by to!()
    /*ireal unarchiveIreal (Id id)
    {
        return unarchivePrimitive!(ireal)(id);
    }*/

    /// Ditto
    long unarchiveLong (Id id)
    {
        return unarchivePrimitive!(long)(id);
    }

    /// Ditto
    real unarchiveReal (Id id)
    {
        return unarchivePrimitive!(real)(id);
    }

    /// Ditto
    short unarchiveShort (Id id)
    {
        return unarchivePrimitive!(short)(id);
    }

    /// Ditto
    ubyte unarchiveUbyte (Id id)
    {
        return unarchivePrimitive!(ubyte)(id);
    }

    // currently not implemented but a reserved keyword
    /*ucent unarchiveCcent (Id id)
    {
        return unarchivePrimitive!(ucent)(id);
    }*/

    /// Ditto
    uint unarchiveUint (Id id)
    {
        return unarchivePrimitive!(uint)(id);
    }

    /// Ditto
    ulong unarchiveUlong (Id id)
    {
        return unarchivePrimitive!(ulong)(id);
    }

    /// Ditto
    ushort unarchiveUshort (Id id)
    {
        return unarchivePrimitive!(ushort)(id);
    }

    /// Ditto
    wchar unarchiveWchar (Id id)
    {
        return unarchivePrimitive!(wchar)(id);
    }

    private T unarchivePrimitive (T, U) (U keyOrId)
    {
        auto tag = toData(T.stringof);

        static if (isSomeString!(U))
            auto element = getElement(tag, keyOrId);

        else static if (is(U == Id))
            auto element = getElement(tag, to!(string)(keyOrId), Attributes.idAttribute);

        else
            static assert (false, format!(`Invalid type "`, U, `". Valid types are "string" and "Id"`));

        if (!element.isValid)
            return T.init;

        return fromData!(T)(element.value);
    }

    private doc.Node getElement (Data tag, string key, Data attribute = Attributes.keyAttribute, bool throwOnError = true)
    {
        auto set = lastElement.query()[tag].attribute((doc.Node node) {
            if (node.name == attribute && node.value == key)
                return true;

            return false;
        });

        if (set.nodes.length == 1)
            return set.nodes[0].parent;

        if (throwOnError)
        {
            if (set.nodes.length == 0)
                error(`Could not find an element "` ~ to!(string)(tag) ~ `" with the attribute "` ~ to!(string)(attribute) ~ `" with the value "` ~ to!(string)(key) ~ `".`, [tag, Attributes.keyAttribute, key]);

            else
                error(`Could not unarchive the value with the key "` ~ to!(string)(key) ~ `" due to malformed data.`, [tag, Attributes.keyAttribute, key]);
        }

        return doc.Node.invalid;
    }

    private Data getValueOfAttribute (Data attribute, doc.Node element = doc.Node.invalid)
    {
        if (!element.isValid)
            element = lastElement;

        auto set = element.query().attribute(attribute);

        if (set.nodes.length == 1)
            return set.nodes[0].value;

        else
        {
            if (set.nodes.length == 0)
                error(`Could not find the attribute "` ~ to!(string)(attribute) ~ `".`, [attribute]);

            else
                error(`Could not unarchive the value of the attribute "` ~ to!(string)(attribute) ~ `" due to malformed data.`, [attribute]);
        }

        return null;
    }

    enum errorMessage = "Could not continue unarchiving due to unrecognized data format: ";
}

private:

@property auto restore (alias variable, alias dg) ()
{
    auto tmp = variable;

    scope (exit)
        variable = tmp;

    return dg();
}