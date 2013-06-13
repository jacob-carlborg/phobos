/**
 * Copyright: Copyright (c) 2012-2013 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Nov 7, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module std.serialization.tests.nonmutable;

version (unittest):
private:

import std.serialization.serializer;
import std.serialization.archives.xmlarchive;
import std.serialization.tests.util;
import std.traits;

Serializer serializer;
XmlArchive!(char) archive;

class B
{
	int a;

	pure this (int a)
	{
		this.a = a;
	}

	override equals_t opEquals (Object other)
	{
		if (auto o = cast(B) other)
			return a == o.a;

		return false;
	}
}

class A
{
	const int a;
	immutable int b;
	immutable string c;
	immutable B d;
	immutable(int)* e;

	this (int a, int b, string c, immutable B d, immutable(int)* e)
	{
		this.a = a;
		this.b = b;
		this.c = c;
		this.d = d;
		this.e = e;
	}

	override equals_t opEquals (Object other)
	{
		if (auto o = cast(A) other)
			return a == o.a &&
				b == o.b &&
				c == o.c &&
				d == o.d &&
				*e == *o.e;

		return false;
	}
}

A a;
immutable int ptr = 3;

void beforeEach ()
{
    archive = new XmlArchive!(char);
	serializer = new Serializer(archive);

	a = new A(1, 2, "str", new immutable(B)(3), &ptr);

	serializer.serialize(a);
}

@describe("serialize object with immutable and const fields")
{
	@it("should return a serialized object") unittest
	{
		beforeEach();

		assert(archive.data().containsDefaultXmlContent());
		assert(archive.data().contains(`<object runtimeType="` ~ typeid(A).toString() ~ `" type="` ~ fullyQualifiedName!(A) ~ `" key="0" id="0">`));

		assert(archive.data().containsXmlTag("int", `key="a" id="1"`, "1"));
		assert(archive.data().containsXmlTag("int", `key="b" id="2"`, "2"));
		assert(archive.data().containsXmlTag("string", `type="immutable(char)" length="3" key="c" id="3"`, "str"));

		assert(archive.data().contains(`<object runtimeType="` ~ typeid(B).toString() ~ `" type="immutable(` ~ fullyQualifiedName!(B) ~ `)" key="d" id="4">`));

		assert(archive.data().containsXmlTag("pointer", `key="e" id="6"`));
		assert(archive.data().containsXmlTag("int", `key="1" id="7"`, "3"));
	}
}

@describe("deserialize object")
{
	@it("should return a deserialized object equal to the original object") unittest
	{
	    beforeEach();

		auto aDeserialized = serializer.deserialize!(A)(archive.untypedData);
		assert(a == aDeserialized);
	}
}