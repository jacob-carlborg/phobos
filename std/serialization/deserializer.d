/**
 * Copyright: Copyright (c) 2010-2013 Jacob Carlborg.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 26, 2010
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 *
 * Source: $(PHOBOSSRC std/serialization/_deserializer.d)
 *
 * Macros:
 *  XREF3 = <a href="std_$1_$2.html#$3">$(D std.$1.$2.$3)</a>
 *  XREF4 = <a href="std_$1_$2_$3.html#$4">$(D std.$1.$2.$3.$4)</a>
 */
module std.serialization.deserializer;

import std.algorithm : canFind;
import std.array;
import std.conv;
import std.serialization.archives.archive;
import std.serialization.attribute;
import std.serialization.events;
import std.serialization.registerwrapper;
import std.serialization.serializable;
import std.serialization.serializationexception;
import std.serialization.serializermixin;
import std.traits;

/**
 * This class represents a deserializer. It's the main interface to the deserialization
 * process and it's this class that actually performs most of the deserialization.
 *
 * The deserializer is the frontend in the deserialization process, it's independent of the
 * underlying archive type. It's responsible for collecting and tracking all values that
 * should be deserialized. It's the deserializer that adds keys and ID's to all values,
 * keeps track of references to make sure that a given value (of reference type) is only
 * deserialized once.
 *
 * The deserializer is also responsible for breaking up types that the underlying archive
 * cannot handle, into primitive types that archive know how to deserialize.
 *
 * Keys are used by the deserializer to associate a name with a value. It's used to
 * deserialize values independently of the order of the fields of a class or struct.
 * They can also be used by the user to give a name to a value. Keys are unique within
 * it's scope.
 *
 * ID's are an unique identifier associated with each deserialized value. The deserializer
 * uses the ID's to track values when deserializing reference types. An ID is unique
 * across the whole deserialized data.
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
class Deserializer
{
    mixin SerializerMixin;

    /// The type of error callback.
    alias Archive.ErrorCallback ErrorCallback;

    /// The type of the serialized data. This is an untyped format.
    alias Archive.UntypedData Data;

    /// The type of an ID.
    alias Archive.Id Id;

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
    @property ErrorCallback errorCallback ()
    {
        return archive.errorCallback;
    }

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
    @property ErrorCallback errorCallback (ErrorCallback errorCallback)
    {
        return archive.errorCallback = errorCallback;
    }

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
            void function (Deserializer serializer, in Object) [ClassInfo] registeredTypes;
            RegisterBase[string] deserializers;
        }

        Archive archive_;

        size_t keyCounter;
        Id idCounter;

        RegisterBase[string] overriddenDeserializers;

        void*[Id] deserializedReferences;
        void[][Id] deserializedSlices;
        void**[Id] deserializedPointers;
        const(void)*[Id] deserializedValues;

        bool hasBegunDeserializing;

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
    this (Archive archive)
    {
        this.archive_ = archive;

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

    private static void downcastSerialize (U : Object) (Deserializer deserializer, in Object value)
    {
        alias Unqual!(U) T;

        static if (!isNonSerialized!(T)())
        {
            auto casted = cast(T) value;
            assert(casted);
            assert(casted.classinfo is T.classinfo);

            deserializer.aggregateDeserializeHelper(casted);
        }
    }

    /**
     * Registers a deserializer for the given type.
     *
     * The given callback will be called when a value of the given type is about to
     * be deserialized. This method can be used as an alternative to $(LREF register). This
     * method can also be used as an alternative to Serializable.fromData.
     *
     * This is method should also be used to perform custom deserialization of third party
     * types or when otherwise chaining an already existing type is not desired.
     *
     * Params:
     *     dg = the callback that will be called when value of the given type is about to be deserialized
     *
     * Examples:
     * ---
     * class Base {}
     * class Foo : Base {}
     *
     * auto archive = new XmlArchive!();
     * auto serializer = new Serializer(archive);
     *
     * auto dg = (ref Base value, Serializer serializer, Data key) {
     *     // perform deserialization
     * };
     *
     * Serializer.registerDeserializer!(Foo)(dg);
     * ---
     *
     * See_Also: $(LREF register)
     * See_Also: $(LREF registerSerializer)
     * See_Also: $(XREF3 serialization, serializable, .Serializable.fromData)
     */
    static void registerDeserializer (Derived, Base) (void delegate (ref Base, Serializer, Data) dg)
    {
        Serializer.deserializers[typeid(Derived).toString()] = toDeserializeRegisterWrapper(dg);
    }

    /**
     * Registers a deserializer for the given type.
     *
     * The given callback will be called when a value of the given type is about to
     * be deserialized. This method can be used as an alternative to $(I register). This
     * method can also be used as an alternative to Serializable.fromData.
     *
     * This is method should also be used to perform custom deserialization of third party
     * types or when otherwise chaining an already existing type is not desired.
     *
     * Params:
     *     dg = the callback that will be called when value of the given type is about to be deserialized
     *
     * Examples:
     * ---
     * class Base {}
     * class Foo : Base {}
     *
     * auto archive = new XmlArchive!();
     * auto serializer = new Serializer(archive);
     *
     * void func (ref Base value, Serializer serializer, Data key) {
     *     // perform deserialization
     * }
     *
     * Serializer.registerDeserializer!(Foo)(&func);
     * ---
     *
     * See_Also: $(LREF register)
     * See_Also: $(LREF registerSerializer)
     * See_Also: $(XREF3 serialization, serializable, .Serializable.fromData)
     */
    static void registerDeserializer (Derived, Base) (void function (ref Base, Serializer, Data) func)
    {
        Serializer.deserializers[typeid(Derived).toString()] = toDeserializeRegisterWrapper(func);
    }

    /**
     * Overrides a globally registered deserializer for the given type with a deserializer
     * local to the receiver.
     *
     * The receiver will first check if a local deserializer is registered, otherwise a global
     * deserializer will be used (if available).
     *
     * Params:
     *     dg = the callback that will be called when value of the given type is about to be deserialized
     *
     * Examples:
     * ---
     * class Base {}
     * class Foo : Base {}
     *
     * auto archive = new XmlArchive!();
     * auto serializer = new Serializer(archive);
     *
     * auto dg = (ref Base value, Serializer serializer, Data key) {
     *     // perform deserialization
     * };
     *
     * Serializer.registerSerializer!(Foo)(dg);
     *
     * auto overrideDg = (ref Base value, Serializer serializer, Data key) {
     *     // this will override the above deserializer
     * };
     *
     * serializer.overrideSerializer!(Foo)(overrideDg);
     * ---
     *
     * See_Also: $(LREF register)
     * See_Also: $(LREF registerDeserializer)
     * See_Also: $(XREF3 serialization, serializable, .Serializable.fromData)
     */
    void overrideDeserializer (Derived, Base) (void delegate (ref Base, Serializer, Data) dg)
    {
        overriddenDeserializers[typeid(Derived).toString()] = toDeserializeRegisterWrapper(dg);
    }

    /**
     * Overrides a globally registered deserializer for the given type with a deserializer
     * local to the receiver.
     *
     * The receiver will first check if a local deserializer is registered, otherwise a global
     * deserializer will be used (if available).
     *
     * Params:
     *     dg = the callback that will be called when value of the given type is about to be deserialized
     *
     * Examples:
     * ---
     * class Base {}
     * class Foo : Base {}
     *
     * auto archive = new XmlArchive!();
     * auto serializer = new Serializer(archive);
     *
     * void func (ref Base value, Serializer serializer, Data key) {
     *     // perform deserialization
     * }
     *
     * Serializer.registerSerializer!(Foo)(&func);
     *
     * void overrideFunc (ref Base value, Serializer serializer, Data key) {
     *     // this will override the above deserializer
     * }
     *
     * serializer.overrideSerializer!(Foo)(&overrideFunc);
     * ---
     *
     * See_Also: $(LREF register)
     * See_Also: $(LREF registerDeserializer)
     * See_Also: $(XREF3 serialization, serializable, .Serializable.fromData)
     */
    void overrideDeserializer (Derived, Base) (void function (ref Base, Serializer, Data) func)
    {
        overriddenDeserializers[typeid(Derived).toString()] = toDeserializeRegisterWrapper(func);
    }

    /**
     * Returns the receivers archive.
     *
     * See_Also: $(XREF4 serialization, archives, archive, Archive)
     */
    @property Archive archive ()
    {
        return archive_;
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
    static void resetDeserializers ()
    {
        deserializers = null;
    }

    /**
     * Resets the serializer.
     *
     * All internal data is reset, including the archive. After calling this method the
     * serializer can be used to start a completely new (de)serialization process.
     *
     * See_Also: $(XREF4 serialization, archives, archive, .Archive.reset)
     */
    void reset ()
    {
        resetCounters();

        overriddenDeserializers = null;
        deserializedReferences = null;
        deserializedSlices = null;
        deserializedValues = null;
        deserializedPointers = null;
        hasBegunDeserializing = false;

        archive.reset();
    }

    /**
     * Deserializes the given data to value of the given type.
     *
     * This is the main method used for deserializing data.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * auto serializer = new Serializer(archive);
     *
     * auto data = serializer.serialize(1);
     * auto i = serializer.deserialize!(int)(data);
     *
     * assert(i == 1);
     * ---
     *
     * Params:
     *        T = the type to deserialize the data into
     *     data = the serialized untyped data to deserialize
     *     key = the key associate with the value that was used during serialization.
     *              Do not specify a key if no key was used during serialization.
     *
     * Returns: the deserialized value. A different runtime type can be returned
     *             if the given type is a base class.
     *
     * Throws: $(XREF3 serialization, serializationexception, SerializationException)
     *         if an error occurs
     *
     * See_Also: $(LREF serialize)
     */
    T deserialize (T) (Data data, string key = "")
    {
        if (!hasBegunDeserializing)
            hasBegunDeserializing = true;

        if (key.empty())
            key = nextKey();

        archive.beginUnarchiving(data);
        auto value = deserializeInternal!(T)(key);

        return value;
    }

    /**
     * Deserializes the value with the given associated key.
     *
     * This method should only be called when performing custom an deserializing a value
     * that is part of an class or struct. If this method is called before that actual
     * deserialization process has begun an SerializationException will be thrown.
     * Use this method if a key was specified during the serialization process.
     *
     * Examples:
     * ---
     * class Foo
     * {
     *     int a;
     *
     *     void fromData (Serializer serializer, Serializer.Data key)
     *     {
     *         a = serializer!(int)("a");
     *     }
     * }
     * ---
     *
     * Params:
     *     key = the key associate with the value that was used during serialization.
     *
     * Returns: the deserialized value. A different runtime type can be returned
     *             if the given type is a base class.
     *
     * Throws: $(XREF3 serialization, serializationexception, SerializationException)
     *         if this method is called before
     *            the actual deserialization process has begun.
     *
     * Throws: $(XREF3 serialization, serializationexception, SerializationException)
     *         if an error occurs
     *
     * See_Also: $(LREF deserialize)
     */
    T deserialize (T) (string key)
    {
        if (!hasBegunDeserializing)
            error("Cannot deserialize without any data, this method should"
                "only be called after deserialization has begun.");

        return deserialize!(T)(archive.untypedData, key);
    }

    /**
     * Deserializes the value with the given associated key.
     *
     * This method should only be called when performing custom an deserializing a value
     * that is part of an class or struct. If this method is called before that actual
     * deserialization process has begun an SerializationException will be thrown.
     * Use this method if no key was specified during the serialization process.
     *
     * Examples:
     * ---
     * class Foo
     * {
     *     int a;
     *
     *     void fromData (Serializer serializer, Serializer.Data key)
     *     {
     *         a = serializer!(int)();
     *     }
     * }
     * ---
     *
     * Params:
     *     key = the key associate with the value that was used during serialization.
     *
     * Returns: the deserialized value. A different runtime type can be returned
     *             if the given type is a base class.
     *
     * Throws: $(XREF3 serialization, serializationexception, SerializationException)
     *         if this method is called before the actual deserialization process
     *         has begun.
     *
     * Throws: $(XREF3 serialization, serializationexception, SerializationException)
     *         if an error occurs
     *
     * See_Also: $(LREF deserialize)
     */
    T deserialize (T) ()
    {
        return deserialize!(T)("");
    }

    /**
     * Deserializes the base class(es) of an instance.
     *
     * This method is used when performing custom deserialization of a given type. If this
     * method is not called when performing custom deserialization none of the instance's
     * base classes will be serialized.
     *
     * Params:
     *     value = the instance which base class(es) should be deserialized,
     *                usually $(D_CODE this)
     *
     * Examples:
     * ---
     * class Base {}
     * class Sub : Base
     * {
     *     void fromData (Serializer serializer, Serializer.Data key)
     *     {
     *         // perform deserialization
     *         serializer.deserializeBase(this);
     *     }
     * }
     * ---
     *
     * Throws: $(XREF3 serialization, serializationexception, SerializationException)
     *         if an error occurs
     *
     * See_Also: $(LREF deserialize)
     */
    void deserializeBase (T) (T value)
    {
        static if (isObject!(T) && !is(Unqual!(T) == Object))
            deserializeBaseTypes(value);
    }

    private Unqual!(U) deserializeInternal (U, Key) (Key keyOrId)
    {
        alias Unqual!(U) T;

        static if (isTypedef!(T))
            return deserializeTypedef!(T)(keyOrId);

        else static if (isObject!(T))
            return deserializeObject!(T)(keyOrId);

        else static if (isStruct!(T))
            return deserializeStruct!(T)(keyOrId);

        else static if (isSomeString!(T))
            return deserializeString!(T)(keyOrId);

        else static if (isArray!(T))
            return deserializeArray!(T)(keyOrId);

        else static if (isAssociativeArray!(T))
            return deserializeAssociativeArray!(T)(keyOrId);

        else static if (isPrimitive!(T))
            return deserializePrimitive!(T)(keyOrId);

        else static if (isPointer!(T))
        {
            static if (isFunctionPointer!(T))
                goto error;

            return deserializePointer!(T)(keyOrId).value;
        }

        else static if (isEnum!(T))
            return deserializeEnum!(T)(keyOrId);

        else
        {
            error:
            error(format!(`The type "`, T, `" cannot be deserialized.`));
        }
    }

    private Unqual!(U) deserializeObject (U, Key) (Key keyOrId)
    {
        alias Unqual!(U) T;

        static if (!isNonSerialized!(T)())
        {
            auto id = deserializeReference(keyOrId);

            if (auto reference = getDeserializedReference!(T)(id))
                return *reference;

            T value;
            Object untypedValue;
            nextId();

            archive.unarchiveObject(keyOrId, id, untypedValue, {
                value = cast(T) untypedValue;
                addDeserializedReference(value, id);

                triggerEvents(value, {
                    auto runtimeType = value.classinfo.name;
                    auto runHelper = false;

                    static if (isSomeString!(Key))
                    {
                        if (auto deserializer = runtimeType in overriddenDeserializers)
                            callDeserializer(deserializer, value, keyOrId);

                        else if (auto deserializer = runtimeType in Deserializer.deserializers)
                            callDeserializer(deserializer, value, keyOrId);

                        else static if (isSerializable!(T))
                            value.fromData(this, keyOrId);

                        else
                            runHelper = true;
                    }

                    else
                        runHelper = true;

                    if (runHelper)
                    {
                        if (isBaseClass(value))
                        {
                            if (auto deserializer = value.classinfo in registeredTypes)
                                (*deserializer)(this, value);

                            else
                                error(`The object of the static type "` ~ typeid(T).toString() ~
                                    `" have a different runtime type (` ~ runtimeType ~
                                    `) and therefore needs to either register its type or register a deserializer for its type "`
                                    ~ runtimeType ~ `".`);
                        }

                        else
                            aggregateDeserializeHelper(value);
                    }
                });
            });

            return value;
        }

        else
            return T.init;
    }

    private T deserializeStruct (T, U) (U key)
    {
        T value;

        static if (!isNonSerialized!(T)())
        {
            nextId();

            archive.unarchiveStruct(key, {
                triggerEvents(value, {
                    auto type = toData(typeid(T).toString());
                    auto runHelper = false;

                    static if (isSomeString!(U))
                    {
                        if (auto deserializer = type in overriddenDeserializers)
                            callDeserializer(deserializer, value, key);

                        else if (auto deserializer = type in Serializer.deserializers)
                            callDeserializer(deserializer, value, key);

                        else
                            runHelper = true;
                    }

                    else
                        runHelper = true;

                    if (runHelper)
                    {
                        static if (isSerializable!(T))
                            value.fromData(this, key);

                        else
                            aggregateDeserializeHelper(value);
                    }
                });
            });
        }

        return value;
    }

    private T deserializeString (T) (string key)
    {
        auto slice = deserializeSlice(key);

        if (auto tmp = getDeserializedSlice!(T)(slice))
            return tmp;

        T value;

        if (slice.id != size_t.max)
        {
            static if (is(T == string))
                value = toSlice(archive.unarchiveString(slice.id), slice);

            else static if (is(T == wstring))
                value = toSlice(archive.unarchiveWstring(slice.id), slice);

            else static if (is(T == dstring))
                value = toSlice(archive.unarchiveDstring(slice.id), slice);
        }

        else
        {
            static if (is(T == string))
                value = archive.unarchiveString(key, slice.id);

            else static if (is(T == wstring))
                value = archive.unarchiveWstring(key, slice.id);

            else static if (is(T == dstring))
                value = archive.unarchiveDstring(key, slice.id);
        }

        addDeserializedSlice(value, slice.id);

        return value;
    }

    private T deserializeArray (T) (string key)
    {
        auto slice = deserializeSlice(key);

        if (auto tmp = getDeserializedSlice!(T)(slice))
            return tmp;

        alias ElementTypeOfArray!(T) E;
        alias Unqual!(E) UnqualfiedE;

        UnqualfiedE[] buffer;
        T value;

        auto dg = (size_t length) {
            buffer.length = length;

            foreach (i, ref e ; buffer)
                e = deserializeInternal!(typeof(e))(toData(i));
        };

        if (slice.id != size_t.max) // Deserialize slice
        {
            archive.unarchiveArray(slice.id, dg);
            assumeUnique(buffer, value);
            addDeserializedSlice(value, slice.id);

            return toSlice(value, slice);
        }

        else // Deserialize array
        {
            slice.id = archive.unarchiveArray(key, dg);

            if (auto arr = slice.id in deserializedSlices)
                return cast(T) *arr;

            assumeUnique(buffer, value);
            addDeserializedSlice(value, slice.id);

            return value;
        }
    }

    private T deserializeAssociativeArray (T) (string key)
    {
        auto id = deserializeReference(key);

        if (auto reference = getDeserializedReference!(T)(id))
            return *reference;

        alias KeyType!(T) Key;
        alias ValueType!(T) Value;

        alias Unqual!(Key) UKey;
        alias Unqual!(Value) UValue;

        UValue[UKey] buffer;

        id = archive.unarchiveAssociativeArray(key, (size_t length) {
            for (size_t i = 0; i < length; i++)
            {
                UKey aaKey;
                UValue aaValue;
                auto k = toData(i);

                archive.unarchiveAssociativeArrayKey(k, {
                    aaKey = deserializeInternal!(Key)(k);
                });

                archive.unarchiveAssociativeArrayValue(k, {
                    aaValue = deserializeInternal!(Value)(k);
                });

                buffer[aaKey] = aaValue;
            }
        });

        T value = buffer;
        addDeserializedReference(value, id);

        return value;
    }

    private Pointer!(T) deserializePointer (T) (string key)
    {
        auto pointeeId = deserializeReference(key);

        if (auto reference = getDeserializedReference!(T)(pointeeId))
            return Pointer!(T)(*reference, Id.max);

        alias PointerTarget!(T) BaseType;
        alias Unqual!(BaseType) UnqualfiedBaseType;

        auto pointer = new UnqualfiedBaseType;

        auto pointerId = archive.unarchivePointer(key, {
            if (auto deserializer = key in overriddenDeserializers)
                callDeserializer(deserializer, pointer, key);

            else if (auto deserializer = key in Serializer.deserializers)
                callDeserializer(deserializer, pointer, key);

            else static if (isSerializable!(T))
                pointer.fromData(this, key);

            else
            {
                static if (isVoid!(PointerTarget!(T)))
                    error(`The value with the key "` ~ to!(string)(key) ~ `"` ~
                        format!(` of the type "`, T, `" cannot be deserialized on `
                        `its own, either implement std.serialization.serializable`
                        `.isSerializable or register a deserializer.`));

                else
                {
                    auto k = nextKey();
                    pointeeId = deserializeReference(k);

                    if (pointeeId == Id.max)
                        *pointer = deserializeInternal!(UnqualfiedBaseType)(k);
                }
            }
        });

        if (pointeeId != Id.max)
            *pointer = deserializeInternal!(UnqualfiedBaseType)(pointeeId);

        addDeserializedReference(pointer, pointerId);

        return Pointer!(T)(cast(T) pointer, pointerId, pointeeId);
    }

    private T deserializeEnum (T, U) (U keyOrId)
    {
        alias BaseTypeOfEnum!(T) Enum;

        enum functionName = toUpper(Enum.stringof[0]) ~ Enum.stringof[1 .. $];
        mixin("return cast(T) archive.unarchiveEnum" ~ functionName ~ "(keyOrId);");
    }

    private T deserializePrimitive (T, U) (U keyOrId)
    {
        enum functionName = toUpper(T.stringof[0]) ~ T.stringof[1 .. $];
        mixin("return archive.unarchive" ~ functionName ~ "(keyOrId);");
    }

    private T deserializeTypedef (T, U) (U keyOrId)
    {
        T value;

        archive.unarchiveTypedef!(T)(key, {
            value = cast(T) deserializeInternal!(OriginalType!(T))(nextKey());
        });

        return value;
    }

    private Id deserializeReference (string key)
    {
        return archive.unarchiveReference(key);
    }

    private Slice deserializeSlice (string key)
    {
        return archive.unarchiveSlice(key);
    }

    private void aggregateDeserializeHelper (T) (ref T value)
    {
        static assert(isStruct!(T) || isObject!(T), format!(`The given value of the type "`, T, `" is not a valid type, the only valid types for this method are objects and structs.`));

        static if (isObject!(T))
            auto rawObject = cast(void*) value;

        else
            auto rawObject = cast(void*) &value;

        foreach (i, dummy ; typeof(T.tupleof))
        {
            enum field = nameOfFieldAt!(T, i);
            mixin("alias attributes = getAttributes!(value." ~ field ~ ");");

            static if (attributes.contains!(nonSerialized))
                continue;

            else
            {
                alias TypeOfField!(T, field) QualifiedType;
                alias Unqual!(QualifiedType) Type;

                auto id = deserializeReference(field);
                auto isReference = id != Id.max;
                auto offset = value.tupleof[i].offsetof;
                auto fieldAddress = cast(Type*) (rawObject + offset);

                static if (isPointer!(Type))
                {
                    auto pointer = deserializePointer!(Type)(toData(field));
                    Type pointerValue;

                    if (pointer.hasPointee)
                        pointerValue = getDeserializedValue!(Type)(pointer.pointee);

                    else
                        pointerValue = pointer.value;

                    *fieldAddress = pointerValue;
                    addDeserializedPointer(value.tupleof[i], pointer.id);
                }

                else
                {
                    auto pointer = getDeserializedPointer!(Type*)(id);

                    if (isReference && pointer)
                    {
                        *fieldAddress = **pointer;
                        *pointer = cast(Type*) &value.tupleof[i];
                    }

                    else
                    {
                           *fieldAddress = deserializeInternal!(Type)(toData(field));
                        addDeserializedValue(value.tupleof[i], nextId());
                    }
                }
            }
        }

        static if (isObject!(T) && !is(Unqual!(T) == Object))
            deserializeBaseTypes(value);
    }

    private void deserializeBaseTypes (T : Object) (T value)
    {
        alias BaseTypeTuple!(T)[0] Base;

        static if (!is(Unqual!(Base) == Object))
        {
            archive.unarchiveBaseClass(nextKey());
            Base base = value;
            aggregateDeserializeHelper(base);
        }
    }

    private void addDeserializedReference (T) (T value, Id id)
    {
        static assert(isReference!(T) || isAssociativeArray!(T), format!(`The given type "`, T, `" is not a reference type, i.e. object, pointer or associative array.`));

        deserializedReferences[id] = cast(void*) value;
    }

    private void addDeserializedSlice (T) (T value, Id id)
    {
        static assert(isArray!(T) || isSomeString!(T), format!(`The given type "`, T, `" is not a slice type, i.e. array or string.`));

        deserializedSlices[id] = cast(void[]) value;
    }

    private void addDeserializedValue (T) (ref T value, Id id)
    {
        deserializedValues[id] = &value;
    }

    private void addDeserializedPointer (T) (ref T value, Id id)
    {
        deserializedPointers[id] = cast(void**) &value;
    }

    private T* getDeserializedReference (T) (Id id)
    {
        if (auto reference = id in deserializedReferences)
            return cast(T*) reference;

        return null;
    }

    private T getDeserializedSlice (T) (Slice slice)
    {
        if (auto array = slice.id in deserializedSlices)
        {
            auto typed = cast(T) *array;
            return typed[slice.offset .. slice.offset + slice.length];
        }

        return null;
    }

    private T getDeserializedValue (T) (Id id)
    {
        if (auto value = id in deserializedValues)
            return cast(T) *value;

        return null;
    }

    private T* getDeserializedPointer (T) (Id id)
    {
        if (auto pointer = id in deserializedPointers)
            return cast(T*) *pointer;

        return null;
    }

    private T[] toSlice (T) (T[] array, Slice slice)
    {
        return array[slice.offset .. slice.offset + slice.length];
    }

    void callDeserializer (T) (RegisterBase* baseWrapper, ref T value, string key)
    {
         auto wrapper = cast(DeserializeRegisterWrapper!(T)) *baseWrapper;
         wrapper(value, this, key);
    }

    static private DeserializeRegisterWrapper!(T) toDeserializeRegisterWrapper (T) (void delegate (ref T, Serializer, Data) dg)
    {
        return new DeserializeRegisterWrapper!(T)(dg);
    }

    static private DeserializeRegisterWrapper!(T) toDeserializeRegisterWrapper (T) (void function (ref T, Serializer, Data) func)
    {
        return new DeserializeRegisterWrapper!(T)(func);
    }

    private void triggerEvents (T) (T value, void delegate () dg)
    {
        triggerEvent!(onDeserializing)(value);
            dg();
        triggerEvent!(onDeserialized)(value);
    }
}

private:

struct Pointer (T)
{
    T value;
    Id id = Id.max;
    Id pointee = Id.max;

    @property bool hasPointee ()
    {
        return pointee != Id.max;
    }
}

private char toUpper () (char c)
{
    if (c >= 'a' && c <= 'z')
        return cast(char) (c - 32);

    return c;
}

inout(T)[] assumeUnique (T) (ref T[] source, ref inout(T)[] destination)
{
    destination = cast(inout(T)[]) source;
    source = null;

    return destination;
}

/*
 * Evaluates to true if T has a field with the given name
 *
 * Params:
 *         T = the type of the class/struct
 *         field = the name of the field
 */
template hasField (T, string field)
{
    enum hasField = hasFieldImpl!(T, field, 0);
}

private template hasFieldImpl (T, string field, size_t i)
{
    static if (T.tupleof.length == i)
        enum hasFieldImpl = false;

    else static if (T.tupleof[i].stringof[1 + T.stringof.length + 2 .. $] == field)
        enum hasFieldImpl = true;

    else
        enum hasFieldImpl = hasFieldImpl!(T, field, i + 1);
}

/*
 * Evaluates to the type of the field with the given name
 *
 * Params:
 *         T = the type of the class/struct
 *         field = the name of the field
 */
template TypeOfField (T, string field)
{
    static assert(hasField!(T, field), "The given field \"" ~ field ~ "\" doesn't exist in the type \"" ~ T.stringof ~ "\"");

    alias TypeOfFieldImpl!(T, field, 0) TypeOfField;
}

private template TypeOfFieldImpl (T, string field, size_t i)
{
    static if (T.tupleof[i].stringof[1 + T.stringof.length + 2 .. $] == field)
        alias typeof(T.tupleof[i]) TypeOfFieldImpl;

    else
        alias TypeOfFieldImpl!(T, field, i + 1) TypeOfFieldImpl;
}

/*
 * Evaluates to a string containing the name of the field at given position in the given type.
 *
 * Params:
 *         T = the type of the class/struct
 *         position = the position of the field in the tupleof array
 */
template nameOfFieldAt (T, size_t position)
{
    static assert (position < T.tupleof.length, format!(`The given position "`, position, `" is greater than the number of fields (`, T.tupleof.length, `) in the type "`, T, `"`));

    static if (T.tupleof[position].stringof.length > T.stringof.length + 3)
        enum nameOfFieldAt = T.tupleof[position].stringof[1 + T.stringof.length + 2 .. $];

    else
        enum nameOfFieldAt = "";
}