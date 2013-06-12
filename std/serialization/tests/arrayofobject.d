/**
 * Copyright: Copyright (c) 2013 Jacob Carlborg. All rights reserved.
 * Authors: Juan Manuel
 * Version: Initial created: Apr 14, 2013
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module std.serialization.tests.arrayofobject;

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
	int a;

	this (int value)
	{
		this.a = value;
	}
}

class D
{
	Object[] arr;
}

D d;

void beforeEach ()
{
    archive = new XmlArchive!(char);
	serializer = new Serializer(archive);

	d = new D;
	d.arr = [cast(Object) new A(1), cast(Object) new A(2)].dup;

	Serializer.register!(A);
	serializer.serialize(d);
}

@describe("serialize array")
{
    @it("should not fail to compile while serializing an Object[] array") unittest
    {
        beforeEach();

        assert(archive.data().containsDefaultXmlContent());
		assert(archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(D).toString() ~ `" type="` ~ fullyQualifiedName!(D) ~ `" key="0" id="0"`));
		assert(archive.data().containsXmlTag("array", `type="object.Object" length="2" key="arr" id="1"`));
		assert(archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(A).toString() ~ `" type="const(object.Object)" key="0" id="2"`));
		assert(archive.data().containsXmlTag("int", `key="a" id="3"`, "1"));
		assert(archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(A).toString() ~ `" type="const(object.Object)" key="1" id="4"`));
		assert(archive.data().containsXmlTag("int", `key="a" id="5"`, "2"));
    }
}

@describe("serialize array")
{
    @it("should return a deserialized Object[] array equal to the original array") unittest
    {
        beforeEach();

        auto dDeserialized = serializer.deserialize!(D)(archive.untypedData);

		assert(d.arr.length == dDeserialized.arr.length);
		assert((cast(A) d.arr[0]).a == (cast(A) dDeserialized.arr[0]).a);
		assert((cast(A) d.arr[1]).a == (cast(A) dDeserialized.arr[1]).a);

		Serializer.resetRegisteredTypes();
    }
}