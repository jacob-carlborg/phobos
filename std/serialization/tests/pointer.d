/**
 * Copyright: Copyright (c) 2011-2013 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Aug 6, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module std.serialization.tests.pointer;

version (unittest):
private:

import std.serialization.serializer;
import std.serialization.archives.xmlarchive;
import std.serialization.tests.util;
import std.traits;

Serializer serializer;
XmlArchive!(char) archive;

class F
{
	int value;
	int* ptr;
	int* ptr2;
}

F f;
F fDeserialized;
int pointee;

class OutOfOrder
{
	int* ptr;
	int value;
	int* ptr2;
}

OutOfOrder outOfOrder;
OutOfOrder outOfOrderDeserialized;
int outOfOrderPointee;

void beforeEach ()
{
    archive = new XmlArchive!(char);
	serializer = new Serializer(archive);    
}

void before ()
{
    beforeEach();

    pointee = 3;
	f = new F;
	f.value = 9;
	f.ptr = &f.value;
	f.ptr2 = &pointee;

	serializer.serialize(f);
}

void beforeOutOfOrder ()
{
    beforeEach();

    outOfOrderPointee = 3;
	outOfOrder = new OutOfOrder;
	outOfOrder.value = 9;
	outOfOrder.ptr = &outOfOrder.value;
	outOfOrder.ptr2 = &outOfOrderPointee;

    serializer.serialize(outOfOrder);
}

@describe("serialize pointer")
{
	@it("should return a serialized pointer") unittest
	{
		before();

		assert(archive.data().containsDefaultXmlContent());
		assert(archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(F).toString() ~ `" type="` ~ fullyQualifiedName!(F) ~ `" key="0" id="0"`));
		assert(archive.data().containsXmlTag("int", `key="value" id="1"`, "9"));
		assert(archive.data().containsXmlTag("pointer", `key="ptr" id="2"`));
		assert(archive.data().containsXmlTag("reference", `key="1"`, "1"));
		assert(archive.data().containsXmlTag("pointer", `key="ptr2" id="3"`));
		assert(archive.data().containsXmlTag("int", `key="2" id="4"`, "3"));
	}
}

@describe("deserialize pointer")
{
	@it("should return a deserialized pointer equal to the original pointer") unittest
	{
	    before();
	    fDeserialized = serializer.deserialize!(F)(archive.untypedData);

		assert(*f.ptr == *fDeserialized.ptr);
	}

	@it("the pointer should point to the deserialized value") unittest
	{
	    before();
	    fDeserialized = serializer.deserialize!(F)(archive.untypedData);

		assert(fDeserialized.ptr == &fDeserialized.value);
	}
}

@describe("serialize pointer out of order")
{
	@it("should return a serialized pointer") unittest
	{
        beforeOutOfOrder();

		assert(archive.data().containsDefaultXmlContent());
		assert(archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(OutOfOrder).toString() ~ `" type="` ~ fullyQualifiedName!(OutOfOrder) ~ `" key="0" id="0"`));
		assert(archive.data().containsXmlTag("pointer", `key="ptr" id="1"`));
		assert(archive.data().containsXmlTag("int", `key="1" id="2"`, "9"));
		assert(archive.data().containsXmlTag("reference", `key="value"`, "1"));
		assert(archive.data().containsXmlTag("pointer", `key="ptr2" id="4"`));
		assert(archive.data().containsXmlTag("int", `key="2" id="5"`, "3"));
	}
}

@describe("deserialize pointer out of order")
{
	@it("should return a deserialized pointer equal to the original pointer") unittest
	{
	    beforeOutOfOrder();
    	outOfOrderDeserialized = serializer.deserialize!(OutOfOrder)(archive.untypedData);

		assert(*outOfOrder.ptr == *outOfOrderDeserialized.ptr);
	}

	@it("the pointer should point to the deserialized value") unittest
	{
	    beforeOutOfOrder();
    	outOfOrderDeserialized = serializer.deserialize!(OutOfOrder)(archive.untypedData);

		assert(outOfOrderDeserialized.ptr == &outOfOrderDeserialized.value);
	}
}