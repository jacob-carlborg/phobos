/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Nov 13, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module std.serialization.tests.circularreference;

version (unittest):
private:

import std.serialization.serializer;
import std.serialization.archives.xmlarchive;
import std.serialization.tests.util;
import std.traits;

Serializer serializer;
XmlArchive!(char) archive;

class A
{
	B b;
	int x;
}

class B
{
	A a;
	int y;
}

A a;
B b;

void beforeEach ()
{
    archive = new XmlArchive!(char);
	serializer = new Serializer(archive);

	a = new A;
	a.x = 3;

	b = new B;
	b.y = 4;

	b.a = a;
	a.b = b;

    serializer.serialize(a);
}

@describe("serialize objects with circular reference")
{
	@it("should return a serialized object") unittest
	{
        beforeEach();

		assert(archive.data().containsDefaultXmlContent());
		assert(archive.data().contains(`<object runtimeType="` ~ typeid(A).toString() ~ `" type="` ~ fullyQualifiedName!(A) ~ `" key="0" id="0">`));

		assert(archive.data().contains(`<object runtimeType="` ~ typeid(B).toString() ~ `" type="` ~ fullyQualifiedName!(B) ~ `" key="b" id="1">`));
		assert(archive.data().containsXmlTag("int", `key="y" id="3"`, "4"));

		assert(archive.data().containsXmlTag("int", `key="x" id="4"`, "3"));
	}
}

@describe("deserialize objects with circular reference")
{
	@it("should return a deserialized object equal to the original object") unittest
	{
	    beforeEach();

		auto aDeserialized = serializer.deserialize!(A)(archive.untypedData);

		assert(a is a.b.a);
		assert(a.x == aDeserialized.x);
		assert(a.b.y == aDeserialized.b.y);
	}
}