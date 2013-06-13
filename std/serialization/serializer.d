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
import std.serialization.archives.archive;
import std.serialization.attribute;
import std.serialization.events;
import std.serialization.registerwrapper;
import std.serialization.serializable;
import std.serialization.serializationexception;
import std.traits;

private
{
    enum Mode
    {
        serializing,
        deserializing
    }

    alias Mode.serializing serializing;
    alias Mode.deserializing deserializing;

    private char toUpper () (char c)
    {
        if (c >= 'a' && c <= 'z')
            return cast(char) (c - 32);

        return c;
    }
}

/**
 * This class represents a serializer. It's the main interface to the (de)serialization
 * process and it's this class that actually performs most of the (de)serialization.
 *
 * The serializer is the frontend in the serialization process, it's independent of the
 * underlying archive type. It's responsible for collecting and tracking all values that
 * should be (de)serialized. It's the serializer that adds keys and ID's to all values,
 * keeps track of references to make sure that a given value (of reference type) is only
 * (de)serialized once.
 *
 * The serializer is also responsible for breaking up types that the underlying archive
 * cannot handle, into primitive types that archive know how to (de)serialize.
 *
 * Keys are used by the serializer to associate a name with a value. It's used to
 * deserialize values independently of the order of the fields of a class or struct.
 * They can also be used by the user to give a name to a value. Keys are unique within
 * it's scope.
 *
 * ID's are an unique identifier associated with each serialized value. The serializer
 * uses the ID's to track values when (de)serializing reference types. An ID is unique
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
class Serializer
{
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
            void function (Serializer serializer, in Object, Mode mode) [ClassInfo] registeredTypes;
            RegisterBase[string] serializers;
            RegisterBase[string] deserializers;
        }

        Archive archive_;

        size_t keyCounter;
        Id idCounter;

        RegisterBase[string] overriddenSerializers;
        RegisterBase[string] overriddenDeserializers;

        Id[void*] serializedReferences;
        void*[Id] deserializedReferences;

        Array[Id] serializedArrays;
        void[][Id] deserializedSlices;

        void**[Id] deserializedPointers;

        ValueMeta[void*] serializedValues;

        const(void)*[Id] deserializedValues;

        bool hasBegunSerializing;
        bool hasBegunDeserializing;

        void delegate (SerializationException exception) throwOnErrorCallback;
        void delegate (SerializationException exception) doNothingOnErrorCallback;

        Mode mode;
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

    private static void downcastSerialize (U : Object) (Serializer serializer, in Object value, Mode mode)
    {
        alias Unqual!(U) T;

        static if (!isNonSerialized!(T)())
        {
            auto casted = cast(T) value;
            assert(casted);
            assert(casted.classinfo is T.classinfo);

            if (mode == serializing)
                serializer.objectStructSerializeHelper(casted);

            else
                serializer.objectStructDeserializeHelper(casted);
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
     * See_Also: $(XREF Serializable, toData)
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
     * See_Also: $(XREF Serializable, toData)
     */
    static void registerSerializer (Derived, Base) (void function (Base, Serializer, Data) func)
    {
        Serializer.serializers[typeid(Derived).toString()] = toSerializeRegisterWrapper(func);
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
     * See_Also: $(XREF Serializable, fromData)
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
     * See_Also: $(XREF Serializable, fromData)
     */
    static void registerDeserializer (Derived, Base) (void function (ref Base, Serializer, Data) func)
    {
        Serializer.deserializers[typeid(Derived).toString()] = toDeserializeRegisterWrapper(func);
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
     * See_Also: $(XREF Serializable, toData)
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
     * See_Also: $(XREF Serializable, toData)
     */
    void overrideSerializer (Derived, Base) (void function (Base, Serializer, Data) func)
    {
        overriddenSerializers[typeid(Derived).toString()] = toSerializeRegisterWrapper(func);
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
     * See_Also: $(XREF Serializable, fromData)
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
     * See_Also: $(XREF3 serialization, Serializable, fromData)
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
    static void resetSerializers ()
    {
        serializers = null;
        deserializers = null;
    }

    /**
     * Resets the serializer.
     *
     * All internal data is reset, including the archive. After calling this method the
     * serializer can be used to start a completely new (de)serialization process.
     * 
     * See_Also: $(XREF4 serialization, archives, archive, reset)
     */
    void reset ()
    {
        resetCounters();

        overriddenSerializers = null;
        overriddenDeserializers = null;

        serializedReferences = null;
        deserializedReferences = null;

        serializedArrays = null;
        deserializedSlices = null;

        serializedValues = null;
        deserializedValues = null;

        deserializedPointers = null;

        hasBegunSerializing = false;
        hasBegunDeserializing = false;

        archive.reset();

        mode = Mode.init;
    }

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
    Data serialize (T) (T value, string key = null)
    {
        mode = serializing;

        if (!hasBegunSerializing)
            hasBegunSerializing = true;

        serializeInternal(value, key);
        postProcess();

        return archive.untypedData;
    }

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

    private void serializeInternal (U) (U value, string key = null, Id id = Id.max)
    {
        alias Unqual!(U) T;

        if (!key)
            key = nextKey();

        if (id == Id.max)
            id = nextId();

        archive.beginArchiving();

        static if ( is(T == typedef) )
            serializeTypedef(value, key, id);

        else static if (isObject!(T))
            serializeObject(value, key, id);

        else static if (isStruct!(T))
            serializeStruct(value, key, id);

        else static if (isSomeString!(T))
            serializeString(value, key, id);

        else static if (isArray!(T))
            serializeArray(value, key, id);

        else static if (isAssociativeArray!(T))
            serializeAssociativeArray(value, key, id);

        else static if (isPrimitive!(T))
            serializePrimitive(value, key, id);

        else static if (isPointer!(T))
        {
            static if (isFunctionPointer!(T))
                goto error;

            else
                serializePointer(value, key, id);
        }

        else static if (isEnum!(T))
            serializeEnum(value, key, id);

        else
        {
            error:
            error(format!(`The type "`, T, `" cannot be serialized.`));
        }
    }

    private void serializeObject (T) (T value, string key, Id id)
    {
        auto typeName = typeid(T).toString();

        static if (!isNonSerialized!(T)())
        {
            if (!value)
                return archive.archiveNull(typeName, key);

            auto reference = getSerializedReference(value);

            if (reference != Id.max)
                return archive.archiveReference(key, reference);

            auto runtimeType = value.classinfo.name;

            addSerializedReference(value, id);

            triggerEvents(value, {
                archive.archiveObject(runtimeType, typeName, key, id, {
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
                                (*serializer)(this, value, serializing);

                            else
                                error(`The object of the static type "` ~ typeName ~
                                    `" have a different runtime type (` ~ runtimeType ~
                                    `) and therefore needs to either register its type or register a serializer for its type "`
                                    ~ runtimeType ~ `".`);
                        }

                        else
                            objectStructSerializeHelper(value);
                    }
                });
            });
        }
    }

    private void serializeStruct (T) (T value, string key, Id id)
    {
        static if (!isNonSerialized!(T)())
        {
            string type = typeid(T).toString();

            triggerEvents(value, {
                archive.archiveStruct(type, key, id, {
                    if (auto serializer = type in overriddenSerializers)
                        callSerializer(serializer, value, key);

                    else if (auto serializer = type in Serializer.serializers)
                        callSerializer(serializer, value, key);

                    else
                    {
                        static if (isSerializable!(T))
                            value.toData(this, key);

                        else
                            objectStructSerializeHelper(value);
                    }
                });
            });
        }
    }

    private void serializeString (T) (T value, string key, Id id)
    {
        auto array = Array(cast(void*) value.ptr, value.length, ElementTypeOfArray!(T).sizeof);

        archive.archive(value, key, id);

        if (value.length > 0)
            addSerializedArray(array, id);
    }

    private void serializeArray (T) (T value, string key, Id id)
    {
        auto array = Array(value.ptr, value.length, ElementTypeOfArray!(T).sizeof);

        archive.archiveArray(array, arrayToString!(T)(), key, id, {
            for (size_t i = 0; i < value.length; i++)
            {
                const e = value[i];
                serializeInternal(e, toData(i));
            }
        });

        if (value.length > 0)
            addSerializedArray(array, id);
    }

    private void serializeAssociativeArray (T) (T value, string key, Id id)
    {
        auto reference = getSerializedReference(value);

        if (reference != Id.max)
            return archive.archiveReference(key, reference);

        addSerializedReference(value, id);

        string keyType = typeid(KeyType!(T)).toString();
        string valueType = typeid(ValueType!(T)).toString();

        archive.archiveAssociativeArray(keyType, valueType, value.length, key, id, {
            size_t i;

            foreach(k, v ; value)
            {
                archive.archiveAssociativeArrayKey(toData(i), {
                    serializeInternal(k, toData(i));
                });

                archive.archiveAssociativeArrayValue(toData(i), {
                    serializeInternal(v, toData(i));
                });

                i++;
            }
        });
    }

    private void serializePointer (T) (T value, string key, Id id)
    {
        if (!value)
            return archive.archiveNull(typeid(T).toString(), key);

        auto reference = getSerializedReference(value);

        if (reference != Id.max)
            return archive.archiveReference(key, reference);

        archive.archivePointer(key, id, {
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
                        archive.archiveReference(nextKey(), valueMeta.id);

                    else
                        serializeInternal(*value, nextKey());
                }
            }
        });

        addSerializedReference(value, id);
    }

    private void serializeEnum (T) (T value, string key, Id id)
    {
        alias BaseTypeOfEnum!(T) EnumBaseType;
        auto val = cast(EnumBaseType) value;
        string type = typeid(T).toString();

        archive.archiveEnum(val, type, key, id);
    }

    private void serializePrimitive (T) (T value, string key, Id id)
    {
        archive.archive(value, key, id);
    }

    private void serializeTypedef (T) (T value, string key, Id id)
    {
        archive.archiveTypedef(typeid(T).toString(), key, nextId(), {
            serializeInternal!(OriginalType!(T))(value, nextKey());
        });
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
        mode = deserializing;

        if (hasBegunSerializing && !hasBegunDeserializing)
            resetCounters();

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
                            callSerializer(deserializer, value, keyOrId);

                        else if (auto deserializer = runtimeType in Serializer.deserializers)
                            callSerializer(deserializer, value, keyOrId);

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
                                (*deserializer)(this, value, deserializing);

                            else
                                error(`The object of the static type "` ~ typeid(T).toString() ~
                                    `" have a different runtime type (` ~ runtimeType ~
                                    `) and therefore needs to either register its type or register a deserializer for its type "`
                                    ~ runtimeType ~ `".`);
                        }

                        else
                            objectStructDeserializeHelper(value);
                    }
                });
            });

            return value;
        }

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
                            callSerializer(deserializer, value, key);

                        else if (auto deserializer = type in Serializer.deserializers)
                            callSerializer(deserializer, value, key);

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
                            objectStructDeserializeHelper(value);
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
                callSerializer(deserializer, pointer, key);

            else if (auto deserializer = key in Serializer.deserializers)
                callSerializer(deserializer, pointer, key);

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

    private void objectStructSerializeHelper (T) (ref T value)
    {
        static assert(isStruct!(T) || isObject!(T), format!(`The given value of the type "`, T, `" is not a valid type, the only valid types for this method are objects and structs.`));

        enum nonSerializedFields = collectAnnotations!(T)();

        foreach (i, dummy ; typeof(T.tupleof))
        {
            enum field = nameOfFieldAt!(T, i);
            mixin(`alias getAttributes!(value.` ~ field ~ `) attributes;`);

            static if (attributes.contains!(nonSerialized)() ||
                internalFields.canFind(field) ||
                nonSerializedFields.canFind(field))
            {
                continue;
            }

            alias typeof(T.tupleof[i]) Type;

            auto v = value.tupleof[i];
            auto id = nextId();

            static if (isPointer!(Type))
                auto pointer = v;

            else
                auto pointer = &value.tupleof[i];

            auto reference = getSerializedReference(v);

            if (reference != Id.max)
                archive.archiveReference(field, reference);

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

        static if (isObject!(T) && !is(Unqual!(T) == Object))
            serializeBaseTypes(value);
    }

    private void objectStructDeserializeHelper (T) (ref T value)
    {
        static assert(isStruct!(T) || isObject!(T), format!(`The given value of the type "`, T, `" is not a valid type, the only valid types for this method are objects and structs.`));

        enum nonSerializedFields = collectAnnotations!(T)();

        static if (isObject!(T))
            auto rawObject = cast(void*) value;

        else
            auto rawObject = cast(void*) &value;

        foreach (i, dummy ; typeof(T.tupleof))
        {
            enum field = nameOfFieldAt!(T, i);
            mixin(`alias getAttributes!(value.` ~ field ~ `) attributes;`);

            static if (attributes.contains!(nonSerialized)() ||
                internalFields.canFind(field) ||
                nonSerializedFields.canFind(field))
            {
                continue;
            }

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

        static if (isObject!(T) && !is(Unqual!(T) == Object))
            deserializeBaseTypes(value);
    }

    private void serializeBaseTypes (T : Object) (inout T value)
    {
        alias BaseTypeTuple!(T)[0] Base;

        static if (!is(Unqual!(Base) == Object))
        {
            archive.archiveBaseClass(typeid(Base).toString(), nextKey(), nextId());
            inout Base base = value;
            objectStructSerializeHelper(base);
        }
    }

    private void deserializeBaseTypes (T : Object) (T value)
    {
        alias BaseTypeTuple!(T)[0] Base;

        static if (!is(Unqual!(Base) == Object))
        {
            archive.unarchiveBaseClass(nextKey());
            Base base = value;
            objectStructDeserializeHelper(base);
        }
    }

    private void addSerializedReference (T) (T value, Id id)
    {
        alias Unqual!(T) Type;
        static assert(isReference!(Type) || isAssociativeArray!(Type), format!(`The given type "`, T, `" is not a reference type, i.e. object, pointer or associative array.`));

        serializedReferences[cast(void*) value] = id;
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

    private void addSerializedValue (T) (T* value, Id id, string key)
    {
        serializedValues[value] = ValueMeta(id, key);
    }

    private void addDeserializedValue (T) (ref T value, Id id)
    {
        deserializedValues[id] = &value;
    }

    private void addDeserializedPointer (T) (ref T value, Id id)
    {
        deserializedPointers[id] = cast(void**) &value;
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

    void callSerializer (T) (RegisterBase* baseWrapper, ref T value, string key)
    {
        if (mode == serializing)
        {
            auto wrapper = cast(SerializeRegisterWrapper!(T)) *baseWrapper;
            wrapper(value, this, key);
        }

        else
        {
            auto wrapper = cast(DeserializeRegisterWrapper!(T)) *baseWrapper;
            wrapper(value, this, key);
        }
    }

    static private SerializeRegisterWrapper!(T) toSerializeRegisterWrapper (T) (void delegate (T, Serializer, Data) dg)
    {
        return new SerializeRegisterWrapper!(T)(dg);
    }

    static private SerializeRegisterWrapper!(T) toSerializeRegisterWrapper (T) (void function (T, Serializer, Data) func)
    {
        return new SerializeRegisterWrapper!(T)(func);
    }

    static private DeserializeRegisterWrapper!(T) toDeserializeRegisterWrapper (T) (void delegate (ref T, Serializer, Data) dg)
    {
        return new DeserializeRegisterWrapper!(T)(dg);
    }

    static private DeserializeRegisterWrapper!(T) toDeserializeRegisterWrapper (T) (void function (ref T, Serializer, Data) func)
    {
        return new DeserializeRegisterWrapper!(T)(func);
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
                    archive.archiveSlice(s, sliceKey, arrayKey);
                    foundSlice = true;
                    break;
                }

                else
                    foundSlice = false;
            }

            if (!foundSlice)
                archive.postProcessArray(sliceKey);
        }
    }

    private string arrayToString (T) ()
    {
        return typeid(ElementTypeOfArray!(T)).toString();
    }

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

    private void triggerEvent (string name, T) (T value)
    {
        static assert (isObject!(T) || isStruct!(T), format!(`The given value of the type "`, T, `" is not a valid type, the only valid types for this method are objects and structs.`));

        static if (hasAnnotation!(T, name))
        {
            mixin("auto event = T." ~ name ~ ";");
            event(value);
        }
    }

    private void triggertUdaEvent (alias event, T) (T value)
    {
        static assert (isObject!(T) || isStruct!(T), format!(`The given value of the type "`, T, `" is not a valid type, the only valid types for this method are objects and structs.`));

        foreach (m ; __traits(allMembers, T))
        {
            static if (m != nonSerializedField)
            {
                mixin(`alias getAttributes!(T.` ~ m ~ `) attrs;`);

                static if (attrs.contains!(event)())
                    __traits(getMember, value, m)();
            }
        }
    }

    private void triggerEvents (T) (T value, void delegate () dg)
    {
        if (mode == serializing)
        {
            triggerEvent!(onSerializingField)(value);
            triggertUdaEvent!(onSerializing)(value);
        }

        else
        {
            triggerEvent!(onDeserializingField)(value);
            triggertUdaEvent!(onDeserializing)(value);
        }

        dg();

        if (mode == serializing)
        {
            triggerEvent!(onSerializedField)(value);
            triggertUdaEvent!(onSerialized)(value);
        }

        else
        {
            triggerEvent!(onDeserializedField)(value);
            triggertUdaEvent!(onDeserialized)(value);
        }
    }

    private static bool isNonSerialized (T) ()
    {
        enum nonSerializedFields = collectAnnotations!(T)();

        return nonSerializedFields.canFind("this") || getAttributes!(T).contains!(nonSerialized)();
    }

    private static template hasAnnotation (T, string annotation)
    {
        enum hasAnnotation = is(typeof({ mixin("const a = T." ~ annotation ~ ";"); }));
    }

    private static string[] collectAnnotations (T) ()
    {
        static assert (isObject!(T) || isStruct!(T), format!(`The given value of the type "`, T, `" is not a valid type, the only valid types for this method are objects and structs.`));

        static if (hasAnnotation!(T, nonSerializedField))
            return T.__nonSerialized;

        else
            return [];
    }

    private void error (string message, size_t line = __LINE__)
    {
        if (errorCallback)
            errorCallback()(new SerializationException(message, __FILE__, line));
    }

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
}

/**
 * This struct is a type independent representation of an array. This struct is used
 * when sending an array for archiving from the serializer to the archive.
 */
struct Array
{
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

/**
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

private:

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

// Evaluates to an array of strings containing the names of the fields in the given type
template fieldsOf (T)
{
    enum fieldsOf = fieldsOfImpl!(T, 0);
}

/*
 * Implementation for fieldsOf
 *
 * Returns: an array of strings containing the names of the fields in the given type
 */
template fieldsOfImpl (T, size_t i)
{
    static if (T.tupleof.length == 0)
        enum fieldsOfImpl = [""];

    else static if (T.tupleof.length - 1 == i)
        enum fieldsOfImpl = [T.tupleof[i].stringof[1 + T.stringof.length + 2 .. $]];

    else
        enum fieldsOfImpl = T.tupleof[i].stringof[1 + T.stringof.length + 2 .. $] ~ fieldsOfImpl!(T, i + 1);
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

/*
 * Sets the given value to the filed with the given name
 *
 * Params:
 *     t = an instance of the type that has the field
 *     value = the value to set
 */
void setValueOfField (T, U, string field) (ref T t, U value)
in
{
    static assert(hasField!(T, field), "The given field \"" ~ field ~ "\" doesn't exist in the type \"" ~ T.stringof ~ "\"");
}
body
{
    enum len = T.stringof.length;

    foreach (i, dummy ; typeof(T.tupleof))
    {
        enum f = T.tupleof[i].stringof[1 + len + 2 .. $];

        static if (f == field)
        {
            t.tupleof[i] = value;
            break;
        }
    }
}

/*
 * Gets the value of the field with the given name
 *
 * Params:
 *     t = an instance of the type that has the field
 *
 * Returns: the value of the field
 */
U getValueOfField (T, U, string field) (T t)
in
{
    static assert(hasField!(T, field), "The given field \"" ~ field ~ "\" doesn't exist in the type \"" ~ T.stringof ~ "\"");
}
body
{
    enum len = T.stringof.length;

    foreach (i, dummy ; typeof(T.tupleof))
    {
        enum f = T.tupleof[i].stringof[1 + len + 2 .. $];

        static if (f == field)
            return t.tupleof[i];
    }

    assert(0);
}