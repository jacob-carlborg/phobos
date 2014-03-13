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
import std.serialization.archivers.archiver;
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
 * This interface is used to represent a compile time configuration for the serializer and
 * archivers.
 *
 * This is the default configuration for the serializer. Each archiver also has its default
 * configuration. An archiver may not support all features specified here, which is noted in
 * the archiver specific configuration. An archiver is also free to specify additional
 * configuration options, like formatting of the archived data.
 *
 * A user can disable features of the serializer or an archiver but it can never enabled
 * features of an archiver that aren't supported.
 *
 * The configuration is used by creating a new interface, inheriting from $(XREF SerializerConfig)
 * or an archive specific configuration. Values are "overridden" by creating new enum
 * declarations for the values of interest to change. The configuration is passed to the
 * archiver and the serializer will pick it up as well.
 *
 * Note that although interfaces are used all configurations are preformed at compile time
 * and without any runtime overhead.
 *
 * Example:
 * ---
 * interface NoReferencesConfig : SerializerConfig
 * {
 *  enum references = false;
 * }
 * ---
 */
interface SerializerConfig
{
    /**
     * Supports references.
     *
     * If this option is enabled the serializer will keep track of reference and pointer types,
     * like objects. That means if an object about to be serialized already has been serialized
     * it will not be serialized again. Instead, a reference will be serialized. Later during the
     * deserializing phase the original object will be deserialized and the references are
     * restored to point to the original deserialized object.
     *
     * If this option is disabled the serializer will serializer the same reference multiple
     * times. This will result in multiple copies being created during deserialization.
     *
     * Example:
     * ---
     * class Bar
     * {
     *  int a = 3;
     * }
     *
     * class Foo
     * {
     *  Bar b1;
     *  Bar b2;
     * }
     *
     * auto foo = new Foo;
     * foo.b1 = new Bar;
     * foo.b2 = foo.b1;
     * ---
     *
     * See_Also: $(XREF pointers)
     */
    enum references = true;

    /**
     * Supports internal pointers.
     *
     * This basically means that the serializer will keep track of pointers to fields in the
     * objects being serialized. During deserialization these pointers are restored, pointing
     * to their original fields.
     *
     * Note that this is not the same thing as references above. This feature should be used
     * when pointers to fields in the object graph being serialized are needed.
     *
     * If this option is disabled the serializer will serialize the same pointer multiple
     * times. This will result in multiple copies being created during deserialization.
     *
     * Example:
     * ---
     * struct Foo
     * {
     *  int a = 3;
     *  int* b;
     * }
     *
     * auto foo = Foo();
     * foo.b = &foo.b;
     * ---
     *
     * See_Also: $(XREF references)
     */
    enum pointers = true;

    /**
     * Supports array slices.
     *
     * If this option is enabled the serializer will properly serialize and later restore
     * slices of arrays during deserialization.
     *
     * If this option is disabled the serializer will serialize a slice as a regular array.
     * This will result in a copy of the array during deserialization.
     *
     * Note that enabling this option could result in decreased (de)serialization performance.
     *
     * Example:
     * ---
     * class Foo
     * {
     *  int[] a;
     *  int[] b;
     * }
     *
     * auto foo = new Foo;
     * foo.a = [1, 2, 3, 4];
     * foo.b = foo.a[1 .. $ - 1];
     * ---
     */
    enum slices = true;

    /**
     * Supports (de)serialization events.
     *
     * When this option enabled any type that has registered events will be triggered.
     * Disabling this option will disable events globally.
     *
     * Example:
     * ---
     * class Foo
     * {
     *  int a;
     *
     *  @onSerializing void serializing ()
     *  {
     *      a = 3;
     *  }
     * }
     * ---
     */
    enum events = true;
}

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
 *     auto archiver = new XmlArchive!();
 *     auto serializer = new Serializer;
 *
 *     auto foo = new Foo;
 *     foo.a = 3;
 *
 *     serializer.serialize(foo);
 *     auto foo2 = serializer.deserialize!(Foo)(archiver.untypedData);
 *
 *     writeln(foo2.a); // prints "3"
 *     assert(foo.a == foo2.a);
 * }
 * ---
 */
struct Serializer (Archiver)
{
    mixin SerializerMixin;

    /// The config of the serializer.
    alias config = Archiver.config;

    /// The type of error callback.
    alias Archiver.ErrorCallback ErrorCallback;

    /// The type of the serialized data. This is an untyped format.
    alias Archiver.UntypedData Data;

    /// The type of an ID.
    alias Archiver.Id Id;

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
        return archiver.errorCallback;
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
        return archiver.errorCallback = errorCallback;
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
            void function (Serializer serializer, in Object) [ClassInfo] registeredTypes;
            RegisterBase[string] serializers;
        }

        Archiver archiver_;

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
     * Creates a new serializer using the given archiver.
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
    this (Archiver archive)
    {
        this.archiver_ = archive;

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
     * Returns the receiver's archiver.
     *
     * See_Also: $(XREF4 serialization, archives, archive, Archive)
     */
    @property Archiver archiver ()
    {
        return archiver_;
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
     * All internal data is reset, including the archiver. After calling this method the
     * serializer can be used to start a completely new (de)serialization process.
     *
     * See_Also: $(XREF4 serialization, archives, archive, .Archive.reset)
     */
    void reset ()
    {
        resetCounters();

        overriddenSerializers = null;
        serializedReferences = null;
        serializedArrays = null;
        serializedValues = null;
        hasBegunSerializing = false;

        archiver.reset();
    }

    void flush ()
    {
        archiver.flush();
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
    void serialize (T) (T value, string key = null)
    {
        auto shouldFlush = false;

        if (hasBegunSerializing)
            serializeInternal(value, key);

        else
        {
            hasBegunSerializing = true;
            shouldFlush = true;
            archiver.beginArchiving();

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

    /**
     * Indicates the serialization is done.
     *
     * Call this method to when no more objects are expected to be serialized. This allows
     * archives that use nested structure to end their content.
     */
    void done ()
    {
        archiver.done();
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

        archiver.archiveRange(type, length, key, id, {
            foreach (e ; value)
                serializeInternal(e);
        });
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

        archiver.beginArchiving();

        static if (isInputRange!(T) && !isArray!(T))
            unsupportedType();

        else static if ( is(T == typedef) )
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
                unsupportedType();

            else
                serializePointer(value, key, id);
        }

        else static if (isEnum!(T))
            serializeEnum(value, key, id);

        else
            unsupportedType();
    }

    private void serializeObject (T) (T value, string key, Id id)
    {
        auto typeName = typeid(T).toString();

        static if (!isNonSerialized!(T)())
        {
            if (!value)
                return archiver.archiveNull(typeName, key);

            auto reference = getSerializedReference(value);

            if (reference != Id.max)
                return archiver.archiveReference(key, reference);

            auto runtimeType = value.classinfo.name;

            addSerializedReference(value, id);

            triggerEvents(value, {
                archiver.archiveObject(runtimeType, typeName, key, id, {
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
                archiver.archiveStruct(type, key, id, {
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
                });
            });
        }
    }

    private void serializeString (T) (T value, string key, Id id)
    {
        auto array = Array(cast(void*) value.ptr, value.length, ElementTypeOfArray!(T).sizeof);

        archiver.archive(value, key, id);

        if (value.length > 0)
            addSerializedArray(array, id);
    }

    private void serializeArray (T) (T value, string key, Id id)
    {
        auto array = Array(value.ptr, value.length, ElementTypeOfArray!(T).sizeof);

        archiver.archiveArray(array, arrayToString!(T)(), key, id, {
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
            return archiver.archiveReference(key, reference);

        addSerializedReference(value, id);

        string keyType = typeid(KeyType!(T)).toString();
        string valueType = typeid(ValueType!(T)).toString();

        archiver.archiveAssociativeArray(keyType, valueType, value.length, key, id, {
            size_t i;

            foreach(k, v ; value)
            {
                archiver.archiveAssociativeArrayKey(toData(i), {
                    serializeInternal(k, toData(i));
                });

                archiver.archiveAssociativeArrayValue(toData(i), {
                    serializeInternal(v, toData(i));
                });

                i++;
            }
        });
    }

    private void serializePointer (T) (T value, string key, Id id)
    {
        if (!value)
            return archiver.archiveNull(typeid(T).toString(), key);

        auto reference = getSerializedReference(value);

        if (reference != Id.max)
            return archiver.archiveReference(key, reference);

        archiver.archivePointer(key, id, {
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
                        archiver.archiveReference(nextKey(), valueMeta.id);

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

        archiver.archiveEnum(val, type, key, id);
    }

    private void serializePrimitive (T) (T value, string key, Id id)
    {
        archiver.archive(value, key, id);
    }

    private void serializeTypedef (T) (T value, string key, Id id)
    {
        archiver.archiveTypedef(typeid(T).toString(), key, nextId(), {
            serializeInternal!(OriginalType!(T))(value, nextKey());
        });
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
                    archiver.archiveReference(field, reference);

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
            archiver.archiveBaseClass(typeid(Base).toString(), nextKey(), nextId());
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
        auto wrapper = cast(SerializeRegisterWrapper!(T, Serializer)) *baseWrapper;
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
                    archiver.archiveSlice(s, sliceKey, arrayKey);
                    foundSlice = true;
                    break;
                }

                else
                    foundSlice = false;
            }

            if (!foundSlice)
                archiver.postProcessArray(sliceKey);
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
