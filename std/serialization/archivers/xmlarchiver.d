/**
 * Copyright: Copyright (c) 2010-2013 Jacob Carlborg.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 26, 2010
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 *
 * Source: $(PHOBOSSRC std/serialization/archivers/_xmlarchiver.d)
 */
module std.serialization.archivers.xmlarchiver;

import std.conv;
import std.range : ElementType, isInputRange, repeat;
import std.serialization.archivers.archiver;
import std.serialization.archivers.xmlarchivermixin;
import std.serialization.archivers.xmldocument;
import std.serialization.serializer;
import std.serialization.serializermixin;
import std.traits;

/**
 * This class is a concrete implementation of the Archive interface. This archive
 * uses XML as the final format for the serialized data.
 */
final class XmlArchiver (Range, Config = Config) : ArchiverBase!(string)
{
    mixin XmlArchiverMixin!(Config);

    private
    {
        enum indentationString = ' '.repeat(config.indentation).to!(string);

        Data archiveType = "std.xml";
        Data archiveVersion = "1.0.0";

        Range range_;

        XmlDocument doc;
        doc.Node lastElement;
        doc.Node tempElement;

        bool hasBegunArchiving;

        Node[Id] archivedArrays;
        Node[Id] archivedPointers;
    }

    /**
     * Creates a new instance of this class with the give error callback.
     *
     * Params:
     *     range = The output range that backs the archiver. This is where all data will be put.
     *     errorCallback = The callback to be called when an error occurs
     */
    this (Range range, ErrorCallback errorCallback = null)
    {
        super(errorCallback);
        range_ = range;
        doc = new XmlDocument;
    }

    /// Returns the range backing the receiver.
    Range range ()
    {
        return range_;
    }

    /// Starts the archiving process. Call this method before archiving any values.
    public void beginArchiving ()
    {
        if (!hasBegunArchiving)
        {
            static if (config.xmlDeclaration)
            {
                put(xmlDeclaration);

                static if (config.prettyFormat)
                    put("\n");
            }

            static if (config.rootTag)
            {
                put(header);

                static if (config.prettyFormat)
                    put("\n");

                lastElement = doc.tree.element(Tags.dataTag);
            }

            else
                lastElement = doc.tree;

            hasBegunArchiving = true;
        }
    }

    void done ()
    {
        static if (config.rootTag)
        {
            static if (config.prettyFormat)
                put("\n");

            put(footer);
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
        hasBegunArchiving = false;
        doc.reset();
    }

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
    void beginArchiveArray (Array array, string type, string key, Id id)
    {
        pushElement();
        internalArchiveArray(array, type, key, id, Tags.arrayTag);
    }

    void endArchiveArray ()
    {
        popElement();
    }

    private void internalArchiveArray(Array array, string type, string key, Id id, Data tag, Data content = null)
    {
        auto parent = lastElement;

        if (array.length == 0)
            lastElement = lastElement.element(tag);

        else
            lastElement = doc.createNode(tag, content);

        lastElement.attribute(Attributes.typeAttribute, toData(type))
        .attribute(Attributes.lengthAttribute, toData(array.length))
        .attribute(Attributes.keyAttribute, toData(key))
        .attribute(Attributes.idAttribute, toData(id));

        addArchivedArray(id, parent, lastElement, key);
    }

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
    void beginArchiveAssociativeArray (string keyType, string valueType, size_t length, string key, Id id)
    {
        popElement();

        lastElement = lastElement.element(Tags.associativeArrayTag)
        .attribute(Attributes.keyTypeAttribute, toData(keyType))
        .attribute(Attributes.valueTypeAttribute, toData(valueType))
        .attribute(Attributes.lengthAttribute, toData(length))
        .attribute(Attributes.keyAttribute, key)
        .attribute(Attributes.idAttribute, toData(id));
    }

    void endArchiveAssociativeArray ()
    {
        popElement();
    }

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
    void beginArchiveAssociativeArrayKey (string key)
    {
        internalArchiveAAKeyValue(key, Tags.keyTag);
    }

    void endArchiveAssociativeArrayKey ()
    {
        popElement();
    }

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
    void beginArchiveAssociativeArrayValue (string key)
    {
        internalArchiveAAKeyValue(key, Tags.valueTag);
    }

    void endArchiveAssociativeArrayValue ()
    {
        popElement();
    }

    private void internalArchiveAAKeyValue (string key, Data tag)
    {
        pushElement();
        lastElement = lastElement.element(tag)
        .attribute(Attributes.keyAttribute, toData(key));
    }

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
    void archiveEnum (bool value, string type, string key, Id id)
    {
        internalArchiveEnum(value, type, key, id);
    }

    /// Ditto
    void archiveEnum (byte value, string type, string key, Id id)
    {
        internalArchiveEnum(value, type, key, id);
    }

    /// Ditto
    void archiveEnum (char value, string type, string key, Id id)
    {
        internalArchiveEnum(value, type, key, id);
    }

    /// Ditto
    void archiveEnum (dchar value, string type, string key, Id id)
    {
        internalArchiveEnum(value, type, key, id);
    }

    /// Ditto
    void archiveEnum (int value, string type, string key, Id id)
    {
        internalArchiveEnum(value, type, key, id);
    }

    /// Ditto
    void archiveEnum (long value, string type, string key, Id id)
    {
        internalArchiveEnum(value, type, key, id);
    }

    /// Ditto
    void archiveEnum (short value, string type, string key, Id id)
    {
        internalArchiveEnum(value, type, key, id);
    }

    /// Ditto
    void archiveEnum (ubyte value, string type, string key, Id id)
    {
        internalArchiveEnum(value, type, key, id);
    }

    /// Ditto
    void archiveEnum (uint value, string type, string key, Id id)
    {
        internalArchiveEnum(value, type, key, id);
    }

    /// Ditto
    void archiveEnum (ulong value, string type, string key, Id id)
    {
        internalArchiveEnum(value, type, key, id);
    }

    /// Ditto
    void archiveEnum (ushort value, string type, string key, Id id)
    {
        internalArchiveEnum(value, type, key, id);
    }

    /// Ditto
    void archiveEnum (wchar value, string type, string key, Id id)
    {
        internalArchiveEnum(value, type, key, id);
    }

    private void internalArchiveEnum (T) (T value, string type, string key, Id id)
    {
        lastElement.element(Tags.enumTag, toData(value))
        .attribute(Attributes.typeAttribute, toData(type))
        .attribute(Attributes.baseTypeAttribute, toData(T.stringof))
        .attribute(Attributes.keyAttribute, toData(key))
        .attribute(Attributes.idAttribute, toData(id));
    }

    /**
     * Archives a base class.
     *
     * This method is used to indicate that the all following calls to archive a value
     * should be part of the base class. This method is usually called within the
     * callback passed to archiveObject. The archiveObject method can the mark the end
     * of the class.
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
     */
    void archiveBaseClass (string type, string key, Id id)
    {
        lastElement = lastElement.element(Tags.baseTag)
        .attribute(Attributes.typeAttribute, toData(type))
        .attribute(Attributes.keyAttribute, toData(key))
        .attribute(Attributes.idAttribute, toData(id));
    }

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
    void archiveNull (string type, string key)
    {
        lastElement.element(Tags.nullTag)
        .attribute(Attributes.typeAttribute, toData(type))
        .attribute(Attributes.keyAttribute, toData(key));
    }

    /**
     * Archives a range.
     *
     * Examples:
     * ---
     * auto range = [1, 2, 3].map!(e => e * 2);
     * auto archive = new XmlArchive!();
     *
     * beginArchiveRange(typeof(range.first).string, range.length, "range", 0);
     *     // archive the individual elements
     * endArchiveRange();
     * ---
     *
     * Params:
     *     type = the runtime type of an element of the range
     *     length = the length of the range. If not available, size_t.max should be used
     *     key = the key associated with the range
     *     id = the id associated with the array
     */
    void beginArchiveRange (string type, size_t length, string key, Id id)
    {
        pushElement();

        lastElement = lastElement.element(Tags.rangeTag)
        .attribute(Attributes.typeAttribute, toData(type))
        .attribute(Attributes.keyAttribute, toData(key))
        .attribute(Attributes.idAttribute, toData(id));

        if (length != size_t.max)
            lastElement.attribute(Attributes.lengthAttribute, toData(length));
    }

    void endArchiveRange ()
    {
        popElement();
    }

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
     */
    void beginArchiveObject (string runtimeType, string type, string key, Id id)
    {
        pushElement();
        lastElement = lastElement.element(Tags.objectTag)
        .attribute(Attributes.runtimeTypeAttribute, toData(runtimeType))
        .attribute(Attributes.typeAttribute, toData(type))
        .attribute(Attributes.keyAttribute, toData(key))
        .attribute(Attributes.idAttribute, toData(id));
    }

    void endArchiveObject ()
    {
        popElement();
    }

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
    void beginArchivePointer (string key, Id id)
    {
        pushElement();
        lastElement = lastElement.element(Tags.pointerTag)
        .attribute(Attributes.keyAttribute, toData(key))
        .attribute(Attributes.idAttribute, toData(id));
    }

    void endArchivePointer ()
    {
        popElement();
    }

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
    void archiveReference (string key, Id id)
    {
        lastElement.element(Tags.referenceTag, toData(id))
        .attribute(Attributes.keyAttribute, toData(key));
    }

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
    void archiveSlice (Slice slice, Id sliceId, Id arrayId)
    {
        if (auto sliceNode = getArchivedArray(sliceId))
        {
            if (auto arrayNode = getArchivedArray(arrayId))
            {
                sliceNode.parent.element(Tags.sliceTag, toData(arrayNode.id))
                .attribute(Attributes.keyAttribute, toData(sliceNode.key))
                .attribute(Attributes.offsetAttribute, toData(slice.offset))
                .attribute(Attributes.lengthAttribute, toData(slice.length));
            }
        }
    }

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
    void beginArchiveStruct (string type, string key, Id id)
    {
        pushElement();
        lastElement = lastElement.element(Tags.structTag)
        .attribute(Attributes.typeAttribute, toData(type))
        .attribute(Attributes.keyAttribute, toData(key))
        .attribute(Attributes.idAttribute, toData(id));
    }

    void endArchiveStruct ()
    {
        popElement();
    }

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
    void beginArchiveTypedef (string type, string key, Id id)
    {
        pushElement();
        lastElement = lastElement.element(Tags.typedefTag)
        .attribute(Attributes.typeAttribute, toData(type))
        .attribute(Attributes.keyAttribute, toData(key))
        .attribute(Attributes.idAttribute, toData(id));
    }

    void endArchiveTypedef ()
    {
        popElement();
    }

    /**
     * Archives the given value.
     *
     * Params:
     *     value = the value to archive
     *     key = the key associated with the value
     *     id = the id associated wit the value
     */
    void archive (string value, string key, Id id)
    {
        archiveString(value, key, id);
    }

    /// Ditto
    void archive (wstring value, string key, Id id)
    {
        archiveString(value, key, id);
    }

    /// Ditto
    void archive (dstring value, string key, Id id)
    {
        archiveString(value, key, id);
    }

    private void archiveString (T) (T value, string key, Id id)
    {
        restore!(lastElement, {
            alias ElementTypeOfArray!(T) ElementType;
            auto array = Array(value.ptr, value.length, ElementType.sizeof);

            internalArchiveArray(array, ElementType.stringof, key, id, Tags.stringTag, toData(value));
        });
    }

    /// Ditto
    void archive (bool value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    /// Ditto
    void archive (byte value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    //currently not suppported by to!()
    /*void archive (cdouble value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }*/

    //currently not implemented but a reserved keyword
    /*void archive (cent value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }*/

    //currently not suppported by to!()
    /*void archive (cfloat value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }*/

    /// Ditto
    void archive (char value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    //currently not suppported by to!()
    /*void archive (creal value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }*/

    /// Ditto
    void archive (dchar value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    /// Ditto
    void archive (double value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    /// Ditto
    void archive (float value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    //currently not suppported by to!()
    /*void archive (idouble value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }*/

    //currently not suppported by to!()
    /*void archive (ifloat value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }*/

    /// Ditto
    void archive (int value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    //currently not suppported by to!()
    /*void archive (ireal value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }*/

    /// Ditto
    void archive (long value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    /// Ditto
    void archive (real value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    /// Ditto
    void archive (short value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    /// Ditto
    void archive (ubyte value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    //currently not implemented but a reserved keyword
    /*void archive (ucent value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }*/

    /// Ditto
    void archive (uint value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    /// Ditto
    void archive (ulong value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    /// Ditto
    void archive (ushort value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    /// Ditto
    void archive (wchar value, string key, Id id)
    {
        archivePrimitive(value, key, id);
    }

    private void archivePrimitive (T) (T value, string key, Id id)
    {
        lastElement.element(toData(T.stringof), toData(value))
        .attribute(Attributes.keyAttribute, toData(key))
        .attribute(Attributes.idAttribute, toData(id));
    }

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
    void postProcessArray (Id id)
    {
        if (auto array = getArchivedArray(id))
            array.parent.attach(array.node);
    }

    /// Flushes the archiver and outputs its data to the internal output range.
    void flush ()
    {
        static if (config.prettyFormat)
        {
            static if (config.rootTag)
            {
                enum prefix = indentationString;
                enum suffix = '\n' ~ indentationString;
            }

            else
            {
                enum prefix = "";
                enum suffix = "\n";
            }

            immutable data = prefix ~ lastElement.pretty(config.indentation).join(suffix);
        }

        else
            immutable data = lastElement.toString();

        put(data);
    }

private:

    void addArchivedArray (Id id, doc.Node parent, doc.Node element, string key)
    {
        archivedArrays[id] = Node(parent, element, id, key);
    }

    Node* getArchivedArray (Id id)
    {
        if (auto array = id in archivedArrays)
            return array;

        error(`Could not continue archiving due to no array with the Id "` ~ to!(string)(id) ~ `" was found.`, [to!(string)(id)]);

        return null;
    }

    Node* getArchivedPointer (Id id)
    {
        if (auto pointer = id in archivedPointers)
            return pointer;

        error(`Could not continue archiving due to no pointer with the Id "` ~ to!(string)(id) ~ `" was found.`, [to!(string)(id)]);

        return null;
    }

    doc.Node getElement (Data tag, string key, Data attribute = Attributes.keyAttribute, bool throwOnError = true)
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

    Data getValueOfAttribute (Data attribute, doc.Node element = doc.Node.invalid)
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

    enum errorMessage = "Could not continue archiving due to unrecognized data format: ";

    void pushElement ()
    {
        tempElement = lastElement;
    }

    void popElement ()
    {
        lastElement = tempElement;
    }

    void put (string str)
    {
        range_.put(str);
    }
}

private:

template ElementTypeOfArray(T : T[])
{
    alias T ElementTypeOfArray;
}

@property auto restore (alias variable, alias dg) ()
{
    auto tmp = variable;

    scope (exit)
        variable = tmp;

    return dg();
}