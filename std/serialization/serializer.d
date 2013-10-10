/**
 * Copyright: Copyright (c) 2010-2013 Jacob Carlborg.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 26, 2010
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 *
 * Source: $(PHOBOSSRC std/serialization/_serializer.d)
 *
 * Macros:
 *  XREF3 = <a href="std_$1_$2.html#$3">$(D std.$1.$2.$3)</a>
 *  XREF4 = <a href="std_$1_$2_$3.html#$4">$(D std.$1.$2.$3.$4)</a>
 */
module std.serialization.serializer;

import std.algorithm : canFind;
import std.array;
import std.conv;
import std.range : isInputRange, hasLength, ElementTypeOfRange = ElementType;
import std.serialization.attribute;
import std.serialization.events;
import std.serialization.registerwrapper;
import std.serialization.serializable;
import std.serialization.serializationexception;
import std.serialization.serializermixin;
import std.string : format;
import std.traits;

/**
 * This class represents a serializer. It's the main interface to the serialization
 * process and it's this class that actually performs most of the serialization.
 *
 * The serializer is the frontend in the serialization process, it's independent of the
 * underlying archive type. It's responsible for collecting and tracking all values that
 * should be serialized. It's the serializer that adds keys and ID's to all values,
 * keeps track of references to make sure that a given value (of reference type) is only
 * serialized once.
 *
 * The serializer is also responsible for breaking up types that the underlying archive
 * cannot handle, into primitive types that archive know how to serialize.
 *
 * Keys are used by the serializer to associate a name with a value. It's used to
 * deserialize values independently of the order of the fields of a class or struct.
 * They can also be used by the user to give a name to a value. Keys are unique within
 * it's scope.
 *
 * ID's are an unique identifier associated with each serialized value. The serializer
 * uses the ID's to track values when serializing reference types. An ID is unique
 * across the whole serialized data.
 *
 * Examples:
 * ---
 * import std.stdio;
 * import std.serialization;
 * import std.serialization.archives;
 *
 * class Foo
 * {
 *     int a;
 * }
 *
 * void main ()
 * {
 *     auto archive = new XmlArchive!();
 *     auto serializer = new Serializer;
 *
 *     auto foo = new Foo;
 *     foo.a = 3;
 *
 *     serializer.serialize(foo);
 *     auto foo2 = serializer.deserialize!(Foo)(archive.untypedData);
 *
 *     writeln(foo2.a); // prints "3"
 *     assert(foo.a == foo2.a);
 * }
 * ---
 */
abstract class Serializer
{
    mixin SerializerMixin;

    /**
     * This is the type of an error callback which is called when an unexpected event occurs.
     *
     * Params:
     *     exception = the exception indicating what error occurred
     *     data = arbitrary data pass along, deprecated
     *
     * See_Also: $(LREF errorCallback)
     */
    alias void delegate (SerializationException exception) ErrorCallback;

    /// The type of the serialized data. This is an untyped format.
    alias Data = immutable(void)[];

    /// The type of an ID.
    alias Id = size_t;

    /**
     * This callback will be called when an unexpected event occurs, i.e. an expected element
     * is missing in the deserialization process.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * auto serializer = new Serializer(archive);
     * serializer.errorCallback = (SerializationException exception) {
     *     writeln(exception);
     *     throw exception;
     * };
     * ---
     */
    @property abstract ErrorCallback errorCallback ();

    /**
     * This callback will be called when an unexpected event occurs, i.e. an expected element
     * is missing in the deserialization process.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * auto serializer = new Serializer(archive);
     * serializer.errorCallback = (SerializationException exception) {
     *     writeln(exception);
     *     throw exception;
     * };
     * ---
     */
    @property abstract ErrorCallback errorCallback (ErrorCallback errorCallback);

    private
    {
        struct ValueMeta
        {
            Id id = Id.max;
            string key;

            @property bool isValid ()
            {
                return id != Id.max && key.length > 0;
            }
        }

        static
        {
            void function (Serializer serializer, in Object) [ClassInfo] registeredTypes;
            RegisterBase[string] serializers;
        }

        size_t keyCounter;
        Id idCounter;

        RegisterBase[string] overriddenSerializers;

        Id[void*] serializedReferences;

        Array[Id] serializedArrays;

        ValueMeta[void*] serializedValues;

        bool hasBegunSerializing;

        void delegate (SerializationException exception) throwOnErrorCallback;
        void delegate (SerializationException exception) doNothingOnErrorCallback;
    }

    /**
     * Creates a new serializer using the given archive.
     *
     * The archive is the backend of the (de)serialization process, it performs the low
     * level (de)serialization of primitive values and it decides the final format of the
     * serialized data.
     *
     * Params:
     *     archive = the archive that should be used for this serializer
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * auto serializer = new Serializer(archive);
     * ---
     */
    protected this ()
    {
        throwOnErrorCallback = (SerializationException exception) { throw exception; };
        doNothingOnErrorCallback = (SerializationException exception) { /* do nothing */ };

        setThrowOnErrorCallback();
    }

    /**
     * Registers the given type for (de)serialization.
     *
     * This method is used for register classes that will be (de)serialized through base
     * class references, no other types need to be registered. If the the user tries to
     * (de)serialize an instance through a base class reference which runtime type is not
     * registered an exception will be thrown.
     *
     * Params:
     *     T = the type to register, must be a class
     *
     * Examples:
     * ---
     * class Base {}
     * class Sub : Base {}
     *
     * Serializer.register!(Sub);
     *
     * auto archive = new XmlArchive!();
     * auto serializer = new Serializer(archive);
     *
     * Base b = new Sub;
     * serializer.serialize(b);
     * ---
     *
     * See_Also: $(LREF registerSerializer)
     * See_Also: $(LREF registerDeserializer)
     */
    @property static void register (T : Object) ()
    {
        registeredTypes[T.classinfo] = &downcastSerialize!(T);
    }

    private static void downcastSerialize (U : Object) (Serializer serializer, in Object value)
    {
        alias Unqual!(U) T;

        static if (!isNonSerialized!(T)())
        {
            auto casted = cast(T) value;
            assert(casted);
            assert(casted.classinfo is T.classinfo);
            serializer.aggregateSerializeHelper(casted);
        }
    }

    /**
     * Registers a serializer for the given type.
     *
     * The given callback will be called when a value of the given type is about to
     * be serialized. This method can be used as an alternative to $(LREF register). This
     * method can also be used as an alternative to Serializable.toData.
     *
     * This is method should also be used to perform custom serialization of third party
     * types or when otherwise chaining an already existing type is not desired.
     *
     * Params:
     *     dg = the callback that will be called when value of the given type is about to be serialized
     *
     * Examples:
     * ---
     * class Base {}
     * class Foo : Base {}
     *
     * auto archive = new XmlArchive!();
     * auto serializer = new Serializer(archive);
     *
     * auto dg = (Base value, Serializer serializer, Data key) {
     *     // perform serialization
     * };
     *
     * Serializer.registerSerializer!(Foo)(dg);
     * ---
     *
     * See_Also: $(LREF register)
     * See_Also: $(LREF registerDeserializer)
     * See_Also: $(XREF3 serialization, serializable, .Serializable.toData)
     */
    static void registerSerializer (Derived, Base) (void delegate (Base, Serializer, Data) dg)
    {
        Serializer.serializers[typeid(Derived).toString()] = toSerializeRegisterWrapper(dg);
    }

    /**
     * Registers a serializer for the given type.
     *
     * The given callback will be called when a value of the given type is about to
     * be serialized. This method can be used as an alternative to $(LREF register). This
     * method can also be used as an alternative to Serializable.toData.
     *
     * This is method should also be used to perform custom serialization of third party
     * types or when otherwise chaining an already existing type is not desired.
     *
     * Params:
     *     dg = the callback that will be called when value of the given type is about to be serialized
     *
     * Examples:
     * ---
     * class Base {}
     * class Foo : Base {}
     *
     * auto archive = new XmlArchive!();
     * auto serializer = new Serializer(archive);
     *
     * void func (Base value, Serializer serializer, Data key) {
     *     // perform serialization
     * }
     *
     * Serializer.registerSerializer!(Foo)(&func);
     * ---
     *
     * See_Also: $(LREF register)
     * See_Also: $(LREF registerDeserializer)
     * See_Also: $(XREF3 serialization, serializable, .Serializable.toData)
     */
    static void registerSerializer (Derived, Base) (void function (Base, Serializer, Data) func)
    {
        Serializer.serializers[typeid(Derived).toString()] = toSerializeRegisterWrapper(func);
    }

    /**
     * Overrides a globally registered serializer for the given type with a serializer
     * local to the receiver.
     *
     * The receiver will first check if a local serializer is registered, otherwise a global
     * serializer will be used (if available).
     *
     * Params:
     *     dg = the callback that will be called when value of the given type is about to be serialized
     *
     * Examples:
     * ---
     * class Base {}
     * class Foo : Base {}
     *
     * auto archive = new XmlArchive!();
     * auto serializer = new Serializer(archive);
     *
     * auto dg = (Base value, Serializer serializer, Data key) {
     *     // perform serialization
     * };
     *
     * Serializer.registerSerializer!(Foo)(dg);
     *
     * auto overrideDg = (Base value, Serializer serializer, Data key) {
     *     // this will override the above serializer
     * }
     *
     * serializer.overrideSerializer!(Foo)(overrideDg);
     * ---
     *
     * See_Also: $(LREF register)
     * See_Also: $(LREF registerSerializer)
     * See_Also: $(XREF3 serialization, serializable, .Serializable.toData)
     */
    void overrideSerializer (Derived, Base) (void delegate (Base, Serializer, Data) dg)
    {
        overriddenSerializers[typeid(Derived).toString()] = toSerializeRegisterWrapper(dg);
    }

    /**
     * Overrides a globally registered serializer for the given type with a serializer
     * local to the receiver.
     *
     * The receiver will first check if a local serializer is registered, otherwise a global
     * serializer will be used (if available).
     *
     * Params:
     *     dg = the callback that will be called when value of the given type is about to be serialized
     *
     * Examples:
     * ---
     * class Base {}
     * class Foo : Base {}
     *
     * auto archive = new XmlArchive!();
     * auto serializer = new Serializer(archive);
     *
     * void func (Base value, Serializer serializer, Data key) {
     *     // perform serialization
     * }
     *
     * Serializer.registerSerializer!(Foo)(&func);
     *
     * void overrideFunc (Base value, Serializer serializer, Data key) {
     *     // this will override the above serializer
     * }
     *
     * serializer.overrideSerializer!(Foo)(&overrideFunc);
     * ---
     *
     * See_Also: $(LREF register)
     * See_Also: $(LREF registerSerializer)
     * See_Also: $(XREF3 serialization, serializable, .Serializable.toData)
     */
    void overrideSerializer (Derived, Base) (void function (Base, Serializer, Data) func)
    {
        overriddenSerializers[typeid(Derived).toString()] = toSerializeRegisterWrapper(func);
    }

    /**
     * Set the error callback to throw when an error occurs
     *
     * See_Also: $(LREF setDoNothingOnErrorCallback)
     */
    void setThrowOnErrorCallback ()
    {
        errorCallback = throwOnErrorCallback;
    }

    /**
     * Set the error callback do nothing when an error occurs
     *
     * See_Also: $(LREF setThrowOnErrorCallback)
     */
    void setDoNothingOnErrorCallback ()
    {
        errorCallback = doNothingOnErrorCallback;
    }

    /**
     * Resets all registered types registered via the "register" method
     *
     * See_Also: $(LREF register)
     */
    static void resetRegisteredTypes ()
    {
        registeredTypes = null;
    }

    /**
     * Resets all registered (de)serializers registered via the $(LREF registerSerializer) method.
     * This method will not reset the overridden (de)serializers.
     *
     * See_Also: $(LREF reset)
     * See_Also: $(LREF registerSerializer)
     * See_Also: $(LREF registerDeserializer)
     */
    static void resetSerializers ()
    {
        serializers = null;
    }

    /**
     * Resets the serializer.
     *
     * All internal data is reset, including the archive. After calling this method the
     * serializer can be used to start a completely new (de)serialization process.
     *
     * See_Also: $(XREF4 serialization, archives, archive, .Archive.reset)
     */
    abstract void reset ()
    {
        resetCounters();

        overriddenSerializers = null;
        serializedReferences = null;
        serializedArrays = null;
        serializedValues = null;
        hasBegunSerializing = false;
    }

    abstract void flush ();

    /**
     * Serializes the given value.
     *
     * Params:
     *     value = the value to serialize
     *     key = associates the value with the given key. This key can later be used to
     *              deserialize the value
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * auto serializer = new Serializer(archive);
     *
     * serializer.serialize(1);
     * serializer.serialize(2, "b");
     * ---
     *
     * Returns: return the serialized data, in an untyped format.
     *
     * Throws: $(XREF3 serialization, serializationexception, SerializationException)
     *         if an error occurs
     *
     * See_Also: $(LREF deserialize)
     */
    void serialize (T) (T value, string key = null)
    {
        auto shouldFlush = false;

        if (hasBegunSerializing)
            serializeInternal(value, key);

        else
        {
            shouldFlush = true;
            beginSerialization();

            static if (isInputRange!(T) && !isArray!(T))
                serializeRange(value, key);

            else
                serializeInternal(value, key);
        }

        if (shouldFlush)
        {
            postProcess();
            flush();
        }
    }

	/// ditto
	alias put = serialize;

    /**
     * Indicates the serialization is done.
     *
     * Call this method to when no more objects are expected to be serialized. This allows
     * archives that use nested structure to end their content.
     */
    abstract void done ();

    /**
     * Serializes the base class(es) of an instance.
     *
     * This method is used when performing custom serialization of a given type. If this
     * method is not called when performing custom serialization none of the instance's
     * base classes will be serialized.
     *
     * Params:
     *     value = the instance which base class(es) should be serialized, usually $(D_CODE this)
     *
     * Examples:
     * ---
     * class Base {}
     * class Sub : Base
     * {
     *     void toData (Serializer serializer, Serializer.Data key)
     *     {
     *         // perform serialization
     *         serializer.serializeBase(this);
     *     }
     * }
     * ---
     *
     * Throws: $(XREF3 serialization, serializationexception, SerializationException)
     *         if an error occurs
     *
     * See_Also: $(LREF serialize)
     */
    void serializeBase (T) (T value)
    {
        static if (isObject!(T) && !is(Unqual!(T) == Object))
            serializeBaseTypes(value);
    }

    /// Starts the serialization process. Call this method before serializing any values.
    protected abstract void beginSerialization ();

    /**
     * Serializes a null pointer or reference.
     *
     * Examples:
     * ---
     * int* ptr;
     *
     * auto serializer = new Serializer();
     * serializer.serializeNull(typeid(ptr).toString, "ptr");
     * ---
     *
     * Params:
     *     type = the runtime type of the pointer or reference to serialize
     *     key = the key associated with the null pointer
     */
    protected abstract void serializeNull (string type, string key);

    /**
     * Serializes a reference.
     *
     * A reference is reference to another value. For example, if an object is serialized
     * more than once, the first time it's serialized it will actual serialize the object.
     * The second time the object will be serialized a reference will be serialized instead
     * of the actual object.
     *
     * This method is also used when serializing a pointer that points to a value that has
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
    protected abstract void serializeReference (string key, Id id);

    /**
     * Starts serializing a range.
     *
     * Params:
     *     type = the runtime type of an element of the range
     *     length = the length of the range. If not available, size_t.max should be used
     *     key = the key associated with the range
     *     id = the id associated with the array
     */
    protected abstract void beginSerializeRange (string type, size_t length, string key, Id id);

    protected abstract void endSerializeRange ();

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
    protected abstract void beginSerializeObject (string runtimeType, string type, string key, Id id);

    protected abstract void endSerializeObject ();

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
    protected abstract void beginSerializeStruct (string type, string key, Id id);

    protected abstract void endSerializeStruct ();

    /**
     * Serializes the given value.
     *
     * Params:
     *     value = the value to serialize
     *     key = the key associated with the value
     *     id = the id associated wit the value
     */
    protected abstract void serializeString (string value, string key, Id id);

    /// Ditto
    protected abstract void serializeString (wstring value, string key, Id id);

    /// Ditto
    protected abstract void serializeString (dstring value, string key, Id id);

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
     */
    protected abstract void beginSerializeArray (Array array, string type, string key, Id id);

    protected abstract void endSerializeArray ();

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
     *
     * See_Also: $(LREF archiveAssociativeArrayValue)
     * See_Also: $(LREF archiveAssociativeArrayKey)
     */
    protected abstract void beginSerializeAssociativeArray (string keyType, string valueType, size_t length, string key, Id id);

    protected abstract void endSerializeAssociativeArray ();

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
     */
    protected abstract void beginSerializePointer (string key, Id id);

    protected abstract void endSerializePointer ();

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
     *
     * See_Also: $(LREF archiveAssociativeArray)
     * See_Also: $(LREF archiveAssociativeArrayValue)
     */
    protected abstract void beginSerializeAssociativeArrayKey (string key);

    protected abstract void endSerializeAssociativeArrayKey ();

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
     *
     * See_Also: $(LREF archiveAssociativeArray)
     * See_Also: $(LREF archiveAssociativeArrayKey)
     */
    protected abstract void beginSerializeAssociativeArrayValue (string key);

    protected abstract void endSerializeAssociativeArrayValue ();

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
    protected abstract void beginSerializeTypedef (string type, string key, Id id);

    protected abstract void endSerializeTypedef ();

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
    protected abstract void serializeBaseClass (string type, string key, Id id);

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
    protected abstract void serializeSlice (Slice slice, Id sliceId, Id arrayId);

    /**
     * Serializes the given value.
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
     *     value = the value to serialize
     *     baseType = the base type of the enum
     *     key = the key associated with the value
     *     id = the id associated with the value
     */
    protected abstract void serializeEnum (bool value, string baseType, string key, Id id);

    /// Ditto
    protected abstract void serializeEnum (byte value, string baseType, string key, Id id);

    /// Ditto
    protected abstract void serializeEnum (char value, string baseType, string key, Id id);

    /// Ditto
    protected abstract void serializeEnum (dchar value, string baseType, string key, Id id);

    /// Ditto
    protected abstract void serializeEnum (int value, string baseType, string key, Id id);

    /// Ditto
    protected abstract void serializeEnum (long value, string baseType, string key, Id id);

    /// Ditto
    protected abstract void serializeEnum (short value, string baseType, string key, Id id);

    /// Ditto
    protected abstract void serializeEnum (ubyte value, string baseType, string key, Id id);

    /// Ditto
    protected abstract void serializeEnum (uint value, string baseType, string key, Id id);

    /// Ditto
    protected abstract void serializeEnum (ulong value, string baseType, string key, Id id);

    /// Ditto
    protected abstract void serializeEnum (ushort value, string baseType, string key, Id id);

    /// Ditto
    protected abstract void serializeEnum (wchar value, string baseType, string key, Id id);

    /**
     * Serializes the given value.
     *
     * Params:
     *     value = the value to serialize
     *     key = the key associated with the value
     *     id = the id associated wit the value
     */
    protected abstract void serializePrimitive (bool value, string key, Id id);

    /// Ditto
    protected abstract void serializePrimitive (byte value, string key, Id id);


    //protected abstract void serializePrimitive (cdouble value, string key, Id id); // currently not supported by to!()


    //protected abstract void serializePrimitive (cent value, string key, Id id);

    //protected abstract void serializePrimitive (cfloat value, string key, Id id); // currently not supported by to!()

    /// Ditto
    protected abstract void serializePrimitive (char value, string key, Id id);

    //protected abstract void serializePrimitive (creal value, string key, Id id); // currently not supported by to!()

    /// Ditto
    protected abstract void serializePrimitive (dchar value, string key, Id id);

    /// Ditto
    protected abstract void serializePrimitive (double value, string key, Id id);

    /// Ditto
    protected abstract void serializePrimitive (float value, string key, Id id);


    //protected abstract void serializePrimitive (idouble value, string key, Id id); // currently not supported by to!()

    //protected abstract void serializePrimitive (ifloat value, string key, Id id); // currently not supported by to!()

    /// Ditto
    protected abstract void serializePrimitive (int value, string key, Id id);


    //protected abstract void serializePrimitive (ireal value, string key, Id id); // currently not supported by to!()

    /// Ditto
    protected abstract void serializePrimitive (long value, string key, Id id);

    /// Ditto
    protected abstract void serializePrimitive (real value, string key, Id id);

    /// Ditto
    protected abstract void serializePrimitive (short value, string key, Id id);

    /// Ditto
    protected abstract void serializePrimitive (ubyte value, string key, Id id);

    //protected abstract void serializePrimitive (ucent value, string key, Id id); // currently not implemented but a reserved keyword

    /// Ditto
    protected abstract void serializePrimitive (uint value, string key, Id id);

    /// Ditto
    protected abstract void serializePrimitive (ulong value, string key, Id id);

    /// Ditto
    protected abstract void serializePrimitive (ushort value, string key, Id id);

    /// Ditto
    protected abstract void serializePrimitive (wchar value, string key, Id id);

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
    protected abstract void postProcessArray (Id id);

    private void serializeRange (U) (U value, string key = null, Id id = Id.max)
    {
        alias Unqual!(U) T;

        static if (hasLength!(T))
            immutable length = value.length;

        else
            immutable length = size_t.max;

        immutable type = typeName!(ElementTypeOfRange!(T));

        if (!key)
            key = nextKey();

        if (id == Id.max)
            id = nextId();

        beginSerializeRange(type, length, key, id);

        foreach (e ; value)
            serializeInternal(e);

        endSerializeRange();
    }

    private void serializeInternal (U) (U value, string key = null, Id id = Id.max)
    {
        alias Unqual!(U) T;

        void unsupportedType ()
        {
            error(format(`The type "%s" cannot be serialized.`, typeName!(T)));
        }

        if (!key)
            key = nextKey();

        if (id == Id.max)
            id = nextId();

        static if (isInputRange!(T) && !isArray!(T))
            unsupportedType();

        else static if ( is(T == typedef) )
            serializeTypedef(value, key, id);

        else static if (isObject!(T))
            serializeObject(value, key, id);

        else static if (isStruct!(T))
            serializeStruct(value, key, id);

        else static if (isSomeString!(T))
            serializeStringInternal(value, key, id);

        else static if (isArray!(T))
            serializeArray(value, key, id);

        else static if (isAssociativeArray!(T))
            serializeAssociativeArray(value, key, id);

        else static if (isPrimitive!(T))
            serializePrimitive(value, key, id);

        else static if (isPointer!(T))
        {
            static if (isFunctionPointer!(T))
                unsupportedType();

            else
                serializePointer(value, key, id);
        }

        else static if (isEnum!(T))
            serializeEnumInternal(value, key, id);

        else
            unsupportedType();
    }

    private void serializeObject (T) (T value, string key, Id id)
    {
        auto typeName = typeid(T).toString();

        static if (!isNonSerialized!(T)())
        {
            if (!value)
                return serializeNull(typeName, key);

            auto reference = getSerializedReference(value);

            if (reference != Id.max)
                return serializeReference(key, reference);

            auto runtimeType = value.classinfo.name;

            addSerializedReference(value, id);

            triggerEvents(value, {
                beginSerializeObject(runtimeType, typeName, key, id);
                    if (auto serializer = runtimeType in overriddenSerializers)
                        callSerializer(serializer, value, key);

                    else if (auto serializer = runtimeType in Serializer.serializers)
                        callSerializer(serializer, value, key);

                    else static if (isSerializable!(T))
                        value.toData(this, key);

                    else
                    {
                        if (isBaseClass(value))
                        {
                            if (auto serializer = value.classinfo in registeredTypes)
                                (*serializer)(this, value);

                            else
                                error(`The object of the static type "` ~ typeName ~
                                    `" have a different runtime type (` ~ runtimeType ~
                                    `) and therefore needs to either register its type or register a serializer for its type "`
                                    ~ runtimeType ~ `".`);
                        }

                        else
                            aggregateSerializeHelper(value);
                    }
                endSerializeObject();
            });
        }
    }

    private void serializeStruct (T) (T value, string key, Id id)
    {
        static if (!isNonSerialized!(T)())
        {
            string type = typeid(T).toString();

            triggerEvents(value, {
                beginSerializeStruct(type, key, id);
                    if (auto serializer = type in overriddenSerializers)
                        callSerializer(serializer, value, key);

                    else if (auto serializer = type in Serializer.serializers)
                        callSerializer(serializer, value, key);

                    else
                    {
                        static if (isSerializable!(T))
                            value.toData(this, key);

                        else
                            aggregateSerializeHelper(value);
                    }
                endSerializeStruct();
            });
        }
    }

    private void serializeStringInternal (T) (T value, string key, Id id)
    {
        auto array = Array(cast(void*) value.ptr, value.length, ElementTypeOfArray!(T).sizeof);

        serializeStringInternal(value, key, id);

        if (value.length > 0)
            addSerializedArray(array, id);
    }

    private void serializeArray (T) (T value, string key, Id id)
    {
        auto array = Array(value.ptr, value.length, ElementTypeOfArray!(T).sizeof);

        beginSerializeArray(array, arrayToString!(T)(), key, id);
            for (size_t i = 0; i < value.length; i++)
            {
                const e = value[i];
                serializeInternal(e, toData(i));
            }
        endSerializeArray();

        if (value.length > 0)
            addSerializedArray(array, id);
    }

    private void serializeAssociativeArray (T) (T value, string key, Id id)
    {
        auto reference = getSerializedReference(value);

        if (reference != Id.max)
            return serializeReference(key, reference);

        addSerializedReference(value, id);

        string keyType = typeid(KeyType!(T)).toString();
        string valueType = typeid(ValueType!(T)).toString();

        beginSerializeAssociativeArray(keyType, valueType, value.length, key, id);
            size_t i;

            foreach(k, v ; value)
            {
                beginSerializeAssociativeArrayKey(toData(i));
                    serializeInternal(k, toData(i));
                endSerializeAssociativeArrayKey();

                beginSerializeAssociativeArrayValue(toData(i));
                    serializeInternal(v, toData(i));
                endSerializeAssociativeArrayValue();

                i++;
            }
        endSerializeAssociativeArray();
    }

    private void serializePointer (T) (T value, string key, Id id)
    {
        if (!value)
            return serializeNull(typeid(T).toString(), key);

        auto reference = getSerializedReference(value);

        if (reference != Id.max)
            return serializeReference(key, reference);

        beginSerializePointer(key, id);
            if (auto serializer = key in overriddenSerializers)
                callSerializer(serializer, value, key);

            else if (auto serializer = key in Serializer.serializers)
                callSerializer(serializer, value, key);

            else static if (isSerializable!(T))
                value.toData(this, key);

            else
            {
                static if (isVoid!(PointerTarget!(T)))
                    error(`The value with the key "` ~ to!(string)(key) ~ `"` ~
                        format!(` of the type "`, T, `" cannot be serialized on `,
                        `its own, either implement std.serialization.serializable`,
                        `.isSerializable or register a serializer.`));

                else
                {
                    auto valueMeta = getSerializedValue(value);

                    if (valueMeta.isValid)
                        serializeReference(nextKey(), valueMeta.id);

                    else
                        serializeInternal(*value, nextKey());
                }
            }
        endSerializePointer();

        addSerializedReference(value, id);
    }

    private void serializeEnumInternal (T) (T value, string key, Id id)
    {
        alias BaseTypeOfEnum!(T) EnumBaseType;
        auto val = cast(EnumBaseType) value;
        string type = typeid(T).toString();

        serializeEnum(val, type, key, id);
    }

    private void serializeTypedef (T) (T value, string key, Id id)
    {
        beginSerializeTypedef(typeid(T).toString(), key, nextId());
            serializeInternal!(OriginalType!(T))(value, nextKey());
        endSerializeTypedef();
    }

    private void aggregateSerializeHelper (T) (ref T value)
    {
        static assert(isStruct!(T) || isObject!(T), format!(`The given value of the type "`, T, `" is not a valid type, the only valid types for this method are objects and structs.`));

        foreach (i, dummy ; typeof(T.tupleof))
        {
            enum field = nameOfFieldAt!(T, i);

            mixin(`alias getAttributes!(value.` ~ field ~ `) attributes;`);

            static if (attributes.contains!(nonSerialized))
                continue;

            else
            {
                alias typeof(T.tupleof[i]) Type;

                auto v = value.tupleof[i];
                auto id = nextId();

                static if (isPointer!(Type))
                    auto pointer = v;

                else
                    auto pointer = &value.tupleof[i];

                auto reference = getSerializedReference(v);

                if (reference != Id.max)
                    serializeReference(field, reference);

                else
                {
                    auto valueMeta = getSerializedValue(pointer);

                    if (valueMeta.isValid)
                        serializePointer(pointer, toData(field), id);

                    else
                    {
                        serializeInternal(v, toData(field), id);
                        addSerializedValue(pointer, id, toData(keyCounter));
                    }
                }
            }
        }

        static if (isObject!(T) && !is(Unqual!(T) == Object))
            serializeBaseTypes(value);
    }

    private void serializeBaseTypes (T : Object) (inout T value)
    {
        alias BaseTypeTuple!(T)[0] Base;

        static if (!is(Unqual!(Base) == Object))
        {
            serializeBaseClass(typeid(Base).toString(), nextKey(), nextId());
            inout Base base = value;
            aggregateSerializeHelper(base);
        }
    }

    private void addSerializedReference (T) (T value, Id id)
    {
        alias Unqual!(T) Type;
        static assert(isReference!(Type) || isAssociativeArray!(Type), format!(`The given type "`, T, `" is not a reference type, i.e. object, pointer or associative array.`));

        serializedReferences[cast(void*) value] = id;
    }

    private void addSerializedValue (T) (T* value, Id id, string key)
    {
        serializedValues[value] = ValueMeta(id, key);
    }

    private Id getSerializedReference (T) (T value)
    {
        if (auto tmp = *(cast(void**) &value) in serializedReferences)
            return *tmp;

        return Id.max;
    }

    private ValueMeta getSerializedValue (T) (T* value)
    {
        if (auto tmp = value in serializedValues)
            return *tmp;

        return ValueMeta();
    }

    void callSerializer (T) (RegisterBase* baseWrapper, ref T value, string key)
    {
        auto wrapper = cast(SerializeRegisterWrapper!(T)) *baseWrapper;
        wrapper(value, this, key);
    }

    static private SerializeRegisterWrapper!(T) toSerializeRegisterWrapper (T) (void delegate (T, Serializer, Data) dg)
    {
        return new SerializeRegisterWrapper!(T)(dg);
    }

    static private SerializeRegisterWrapper!(T) toSerializeRegisterWrapper (T) (void function (T, Serializer, Data) func)
    {
        return new SerializeRegisterWrapper!(T)(func);
    }

    private void addSerializedArray (Array array, Id id)
    {
        serializedArrays[id] = array;
    }

    private void postProcess ()
    {
        postProcessArrays();
    }

    private void postProcessArrays ()
    {
        bool foundSlice = true;

        foreach (sliceKey, slice ; serializedArrays)
        {
            foreach (arrayKey, array ; serializedArrays)
            {
                if (slice.isSliceOf(array) && slice != array)
                {
                    auto s = Slice(slice.length, (slice.ptr - array.ptr) / slice.elementSize);
                    serializeSlice(s, sliceKey, arrayKey);
                    foundSlice = true;
                    break;
                }

                else
                    foundSlice = false;
            }

            if (!foundSlice)
                postProcessArray(sliceKey);
        }
    }

    private string arrayToString (T) ()
    {
        return typeid(ElementTypeOfArray!(T)).toString();
    }

    private void triggerEvents (T) (T value, void delegate () dg)
    {
        triggerEvent!(onSerializing)(value);
            dg();
        triggerEvent!(onSerialized)(value);
    }
}

private:

string typeName (T) ()
{
    return typeid(T).toString();
}
