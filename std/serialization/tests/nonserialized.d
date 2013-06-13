/**
 * Copyright: Copyright (c) 2011-2013 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Aug 20, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module std.serialization.tests.nonserialized;

version (unittest):
private:

import std.serialization.serializer;
import std.serialization.serializable;
import std.serialization.archives.xmlarchive;
import std.serialization.tests.util;
import std.traits;

Serializer serializer;
XmlArchive!(char) archive;

class Bar
{
	mixin NonSerialized;

	int c;
}

@nonSerialized class Baz
{
	int c;
}

class Foo
{
	int a;
	int b;
	@nonSerialized int c;
	Bar bar;
	Baz baz;

	mixin NonSerialized!(a);
}

Foo foo;

void beforeEach ()
{
    archive = new XmlArchive!(char);
	serializer = new Serializer(archive);

	foo = new Foo;
	foo.a = 3;
	foo.b = 4;
	foo.c = 5;

	foo.bar = new Bar;
	foo.baz = new Baz;

    serializer.serialize(foo);
}

@describe("serialize object with a non-serialized field")
{
	@it("should return serialized object with only one serialized field") unittest
	{
		beforeEach();

		assert(archive.data().containsDefaultXmlContent());
		assert(archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(Foo).toString() ~ `" type="` ~ fullyQualifiedName!(Foo) ~ `" key="0" id="0"`));
		assert(archive.data().containsXmlTag("int", `key="b" id="1"`, "4"));

		assert(!archive.data().containsXmlTag("int", `key="a" id="1"`, "3"));
		assert(!archive.data().containsXmlTag("int", `key="c" id="3"`, "5"));

		assert(!archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(Bar).toString() ~ `" type="Bar" key="bar" id="4"`));
		assert(!archive.data().containsXmlTag("int", `key="c" id="5"`, "0"));
		assert(!archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(Baz).toString() ~ `" type="Baz" key="bar" id="6"`));
		assert(!archive.data().containsXmlTag("int", `key="c" id="7"`, "0"));
	}
}

@describe("deserialize object with a non-serialized field")
{
	@it("short return deserialized object equal to the original object, where only one field is deserialized") unittest
	{
	    beforeEach();

		auto f = serializer.deserialize!(Foo)(archive.untypedData);

		assert(f.a == foo.a.init);
		assert(f.b == foo.b);
		assert(f.c == foo.c.init);
		assert(f.bar is foo.bar.init);
		assert(f.baz is foo.baz.init);
	}
}