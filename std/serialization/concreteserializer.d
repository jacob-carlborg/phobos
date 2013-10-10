/**
 * Copyright: Copyright (c) 2013 Jacob Carlborg.
 * Authors: Jacob Carlborg
 * Version: Initial created: Sep 24, 2013
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 *
 * Source: $(PHOBOSSRC std/serialization/_serializer.d)
 *
 * Macros:
 *  XREF3 = <a href="std_$1_$2.html#$3">$(D std.$1.$2.$3)</a>
 *  XREF4 = <a href="std_$1_$2_$3.html#$4">$(D std.$1.$2.$3.$4)</a>
 */
module std.serialization.concreteserializer;

import std.algorithm;
import std.array;
import std.serialization.serializer;
import std.serialization.serializermixin;

final class ConcreteSerializer (Archiver) : Serializer
{
    /// The type of error callback.
    alias ErrorCallback = Serializer.ErrorCallback;
    
	private
	{
	    Archiver archiver_;
	    ErrorCallback errorCallback_;
    }

	this (Archiver archiver)
	{
		super();
		this.archiver_ = archiver;
	}

	/**
     * Returns the receiver's archive.
     *
     * See_Also: $(XREF4 serialization, archives, archive, Archive)
     */
    @property Archiver archiver ()
    {
        return archiver_;
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
    @property override ErrorCallback errorCallback ()
    {
        return errorCallback_;
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
    @property override ErrorCallback errorCallback (ErrorCallback errorCallback)
    {
        return errorCallback_ = errorCallback;
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
        super.serialize(value, key);
		return archiver.untypedData;
    }

    /**
     * Indicates the serialization is done.
     *
     * Call this method to when no more objects are expected to be serialized. This allows
     * archives that use nested structure to end their content.
     */
    override void done ()
    {
        archiver.done();
    }

    /**
     * Resets the serializer.
     *
     * All internal data is reset, including the archiver. After calling this method the
     * serializer can be used to start a completely new (de)serialization process.
     *
     * See_Also: $(XREF4 serialization, archives, archive, .Archive.reset)
     */
	override void reset ()
	{
		super.reset();
		archiver.reset();
	}

    /// Flushes the archiver and outputs its data to the internal output range.
    override void flush ()
    {
        archiver.flush();
    }

    mixin ForwardMethods!(
        Method!(Serializer.beginSerialization),
        Method!(Serializer.serializeNull),
        Method!(Serializer.serializeReference),
        Method!(Serializer.beginSerializeRange),
        Method!(Serializer.endSerializeRange),
        Method!(Serializer.beginSerializeObject),
        Method!(Serializer.endSerializeObject),
        Method!(Serializer.beginSerializeStruct),
        Method!(Serializer.endSerializeStruct),
        Method!(Serializer.serializeString, string, string, Id),
        Method!(Serializer.serializeString, wstring, string, Id),
        Method!(Serializer.serializeString, dstring, string, Id),
        Method!(Serializer.beginSerializeArray),
        Method!(Serializer.endSerializeArray),
        Method!(Serializer.beginSerializeAssociativeArray),
        Method!(Serializer.endSerializeAssociativeArray),
        Method!(Serializer.beginSerializePointer),
        Method!(Serializer.endSerializePointer),
        Method!(Serializer.beginSerializeAssociativeArrayKey),
        Method!(Serializer.endSerializeAssociativeArrayKey),
        Method!(Serializer.beginSerializeAssociativeArrayValue),
        Method!(Serializer.endSerializeAssociativeArrayValue),
        Method!(Serializer.beginSerializeTypedef),
        Method!(Serializer.endSerializeTypedef),
        Method!(Serializer.serializeBaseClass),
        Method!(Serializer.serializeSlice),

        Method!(Serializer.serializeEnum, bool, string, string, Id),
        Method!(Serializer.serializeEnum, byte, string, string, Id),
        Method!(Serializer.serializeEnum, char, string, string, Id),
        Method!(Serializer.serializeEnum, dchar, string, string, Id),
        Method!(Serializer.serializeEnum, int, string, string, Id),
        Method!(Serializer.serializeEnum, long, string, string, Id),
        Method!(Serializer.serializeEnum, short, string, string, Id),
        Method!(Serializer.serializeEnum, ubyte, string, string, Id),
        Method!(Serializer.serializeEnum, uint, string, string, Id),
        Method!(Serializer.serializeEnum, ulong, string, string, Id),
        Method!(Serializer.serializeEnum, ushort, string, string, Id),
        Method!(Serializer.serializeEnum, wchar, string, string, Id),

        Method!(Serializer.serializePrimitive, bool, string, Id),
        Method!(Serializer.serializePrimitive, byte, string, Id),
        //Method!(Serializer.serializePrimitive, cdouble, string, Id), // currently not supported by to!()
        //Method!(Serializer.serializePrimitive, cent, string, Id),
        //Method!(Serializer.serializePrimitive, cfloat, string, Id), // currently not supported by to!()
        Method!(Serializer.serializePrimitive, char, string, Id),
        //Method!(Serializer.serializePrimitive, creal, string, Id), // currently not supported by to!()
        Method!(Serializer.serializePrimitive, dchar, string, Id),
        Method!(Serializer.serializePrimitive, double, string, Id),
        Method!(Serializer.serializePrimitive, float, string, Id),
        //Method!(Serializer.serializePrimitive, idouble, string, Id), // currently not supported by to!()
        //Method!(Serializer.serializePrimitive, ifloat, string, Id), // currently not supported by to!()
        Method!(Serializer.serializePrimitive, int, string, Id),
        //Method!(Serializer.serializePrimitive, ireal, string, Id), // currently not supported by to!()
        Method!(Serializer.serializePrimitive, long, string, Id),
        Method!(Serializer.serializePrimitive, real, string, Id),
        Method!(Serializer.serializePrimitive, short, string, Id),
        Method!(Serializer.serializePrimitive, ubyte, string, Id),
        //Method!(Serializer.serializePrimitive, ucent, string, Id), // currently not implemented but a reserved keyword
        Method!(Serializer.serializePrimitive, uint, string, Id),
        Method!(Serializer.serializePrimitive, ulong, string, Id),
        Method!(Serializer.serializePrimitive, ushort, string, Id),
        Method!(Serializer.serializePrimitive, wchar, string, Id),
        Method!(Serializer.postProcessArray)
    );
}

private:

mixin template ForwardMethods (Methods ...)
{
    mixin(generateForwardMethods!(Methods));
}

struct Method (alias method, Types ...)
{
    import std.traits;

    enum name = __traits(identifier, method);

    static if (Types.length > 0)
        alias types = Types;

    else
        alias types = ParameterTypeTuple!(method);
}

string generateForwardMethods (Methods ...) ()
{
    Appender!(string[]) methods;

    foreach (method ; Methods)
        methods ~= generateForwardMethod!(method);

    return methods.data.join("\n");
}

unittest
{
    struct Foo
    {
        void serializeFoo (int a) { }
        void bar (char b) { }
    }

    assert(generateForwardMethods!(Method!(Foo.serializeFoo), Method!(Foo.bar)) ==
        "protected override void serializeFoo(int arg0){archiver_.archiveFoo(arg0);}\n" ~
        "protected override void bar(char arg0){archiver_.bar(arg0);}");
}

string generateForwardMethod (method) ()
{
    auto signature = generateSignature!(method);
    auto body_ = generateBody!(method);

    return signature ~ "{" ~ body_ ~ "}";
}

unittest
{
    struct Foo
    {
        void foo (int a) { }
        void serializeFoo (int b) { }
        void beginSerializeFoo (int a, char b) { }
    }

    assert(generateForwardMethod!(Method!(Foo.foo)) ==
        "protected override void foo(int arg0){archiver_.foo(arg0);}");

    assert(generateForwardMethod!(Method!(Foo.serializeFoo)) ==
        "protected override void serializeFoo(int arg0){archiver_.archiveFoo(arg0);}");

    assert(generateForwardMethod!(Method!(Foo.beginSerializeFoo)) ==
        "protected override void beginSerializeFoo(int arg0, char arg1){archiver_.beginArchiveFoo(arg0, arg1);}");
}

string generateSignature (method) ()
{
    Appender!(string) signature;
    signature ~= "protected override void ";
    signature ~= method.name;

    Appender!(string[]) parameters;

    foreach (i, type ; method.types)
        parameters ~= type.stringof ~ " " ~ parameterName(i);

    signature ~= "(";

    static if (method.types.length > 0)
        signature ~= parameters.data.joiner(", ");

    signature ~= ")";

    return signature.data;
}

unittest
{
    struct Foo
    {
        void serializeFoo (int a) { }
        void serializeBar (int a, char b) { }
        void serializeFoo (Object o) { }
        void beginSerializeFoo () { }
    }

    assert(generateSignature!(Method!("serializeFoo", void function (int))) == 
        "protected override void serializeFoo(int arg0)");

    assert(generateSignature!(Method!("serializeBar", string, void function (int, char))) == 
        "protected override void serializeBar(string arg0, int arg1, char arg2)");

    assert(generateSignature!(Method!("serializeFoo", void function (Object))) == 
        "protected override void serializeFoo(Object arg0)");

    assert(generateSignature!(Method!("beginSerializeFoo")) == 
        "protected override void beginSerializeFoo()");
}

string generateBody (method) ()
{
    auto name = method.name.
        replace("serialize", "archive").
        replace("Serialize", "Archive").
        replace("Serialization", "Archiving");

    Appender!(string[]) arguments;

    foreach (i, type ; method.types)
        arguments ~= parameterName(i);

    Appender!(string) content;

    content ~= "archiver_.";
    content ~= name;
    content ~= "(";

    static if (method.types.length > 0)
        content ~= arguments.data.joiner(", ");

    content ~= ");";

    return content.data;
}

unittest
{
    struct Foo
    {
        void foo (int a) { }
        void serializeFoo (int a) { }
        void bar (int a, char b) { }
        void beginSerializeFoo () { }
    }

    assert(generateBody!(Method!(Foo.foo)) == "archiver_.foo(arg0);");
    assert(generateBody!(Method!(Foo.serializeFoo)) == "archiver_.archiveFoo(arg0);");
    assert(generateBody!(Method!(Foo.bar)) == "archiver_.bar(arg0, arg1);");

    assert(generateBody!(Method!(Foo.beginSerializeFoo)) ==
        "archiver_.beginArchiveFoo(arg0);");
}

string parameterName (size_t i)
{
    import std.conv;

    return "arg" ~ to!(string)(i);
}

unittest
{
    assert(parameterName(0) == "arg0");
    assert(parameterName(1) == "arg1");
    assert(parameterName(10) == "arg10");
}