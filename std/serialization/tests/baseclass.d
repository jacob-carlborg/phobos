/**
 * Copyright: Copyright (c) 2011-2013 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Aug 7, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module std.serialization.tests.baseclass;

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
	int a;
	int[] c;

	int getA ()
	{
		return a;
	}

	int getB ()
	{
		return a;
	}
}

class Sub : Base
{
	int b;

	override int getB ()
	{
		return b;
	}
}

Sub sub;
Base base;

void beforeEach ()
{
    archive = new XmlArchive!(char);
	serializer = new Serializer(archive);

	sub = new Sub;
	sub.a = 3;
	sub.b = 4;
	base = sub;

    Serializer.register!(Sub);
	serializer.serialize(base);
}

@describe("serialize subclass through a base class reference")
{
	@it("should return serialized subclass with the static type \"Base\" and the runtime type \"tests.BaseClass.Sub\"") unittest
	{
	    beforeEach();

        assert(archive.data().containsDefaultXmlContent());
        assert(archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(Sub).toString() ~ `" type="` ~ fullyQualifiedName!(Base) ~ `" key="0" id="0"`));
        assert(archive.data().containsXmlTag("int", `key="b" id="1"`, "4"));
        assert(archive.data().containsXmlTag("base", `type="` ~ fullyQualifiedName!(Base) ~ `" key="1" id="2"`));
        assert(archive.data().containsXmlTag("int", `key="a" id="3"`, "3"));
		assert(archive.data().containsXmlTag("array", `type="inout(int)" length="0" key="c" id="4"`, true));
	}
}

@describe("deserialize subclass through a base class reference")
{
	@it("should return a deserialized subclass with the static type \"Base\" and the runtime type \"tests.BaseClass.Sub\"") unittest
	{
	    beforeEach();

		auto subDeserialized = serializer.deserialize!(Base)(archive.untypedData);

		assert(sub.a == subDeserialized.getA());
		assert(sub.b == subDeserialized.getB());

		Serializer.resetRegisteredTypes();
	}
}