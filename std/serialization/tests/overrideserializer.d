/**
 * Copyright: Copyright (c) 2011-2013 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Dec 20, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module std.serialization.tests.overrideserializer;

version (unittest):
private:

import std.serialization.serializer;
import std.serialization.archives.xmlarchive;
import std.serialization.tests.util;
import std.traits;

Serializer serializer;
XmlArchive!(char) archive;

class Base
{
	int x;
}

class Foo : Base
{
	private int a_;
	private int b_;

	@property int a () { return a_; }
	@property int a (int a) { return a_ = a; }
	@property int b () { return b_; }
	@property int b (int b) { return b_ = b; }
}

Foo foo;
int i;

void toData (Foo foo, Serializer serializer, Serializer.Data key)
{
	i += 4;
}

void fromData (ref Foo foo, Serializer serializer, Serializer.Data key)
{
	i += 4;
}

void overrideToData (Foo foo, Serializer serializer, Serializer.Data key)
{
	i++;
	serializer.serialize(foo.a, "a");
	serializer.serialize(foo.b, "b");
	serializer.serializeBase(foo);
}

void overrideFromData (ref Foo foo, Serializer serializer, Serializer.Data key)
{
	i++;
	foo.a = serializer.deserialize!(int)("a");
	foo.b = serializer.deserialize!(int)("b");
	serializer.deserializeBase(foo);
}

void beforeEach ()
{
    archive = new XmlArchive!(char);
	serializer = new Serializer(archive);

	foo = new Foo;
	foo.a = 3;
	foo.b = 4;
	foo.x = 5;
	i = 3;

    Serializer.registerSerializer!(Foo)(&toData);
	Serializer.registerDeserializer!(Foo)(&fromData);

	serializer.overrideSerializer!(Foo)(&overrideToData);
	serializer.overrideDeserializer!(Foo)(&overrideFromData);

	serializer.serialize(foo);
}

@describe("serialize object using an overridden serializer")
{
	@it("should return a custom serialized object") unittest
	{
        beforeEach();

		assert(archive.data().containsDefaultXmlContent());
		assert(archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(Foo).toString() ~ `" type="` ~ fullyQualifiedName!(Foo) ~ `" key="0" id="0"`));
		assert(archive.data().containsXmlTag("int", `key="a" id="1"`, "3"));
		assert(archive.data().containsXmlTag("int", `key="b" id="2"`, "4"));

		assert(archive.data().containsXmlTag("base", `type="` ~ fullyQualifiedName!(Base) ~ `" key="1" id="3"`));
		assert(archive.data().containsXmlTag("int", `key="x" id="4"`, "5"));

		assert(i == 4);

        Serializer.resetSerializers();
	}
}

@describe("deserialize object using an overridden deserializer")
{
	@it("short return a custom deserialized object equal to the original object") unittest
	{
	    beforeEach();

		auto f = serializer.deserialize!(Foo)(archive.untypedData);

		assert(foo.a == f.a);
		assert(foo.b == f.b);
		assert(foo.x == f.x);

		assert(i == 5);

		Serializer.resetSerializers();
	}
}