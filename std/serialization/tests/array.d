/**
 * Copyright: Copyright (c) 2011-2013 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Aug 6, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module std.serialization.tests.array;

version (unittest):
private:

import std.serialization.serializer;
import std.serialization.archives.xmlarchive;
import std.serialization.tests.util;
import std.traits;

class D
{
	int[] arr;
}

D d;

XmlArchive!(char) archive;
Serializer serializer;

void beforeEach ()
{
    archive = new XmlArchive!(char);
	serializer = new Serializer(archive);

	d = new D;
	d.arr = [27, 382, 283, 3820, 32, 832].dup;
    serializer.serialize(d);
}

@describe("serialize array")
{
    @it("should return a serialized array") unittest
    {
        beforeEach();

        assert(archive.data().containsDefaultXmlContent());
        assert(archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(D).toString() ~ `" type="` ~ fullyQualifiedName!(D) ~`" key="0" id="0"`));
        assert(archive.data().containsXmlTag("array", `type="int" length="6" key="arr" id="1"`));
        assert(archive.data().containsXmlTag("int", `key="0" id="2"`, "27"));
        assert(archive.data().containsXmlTag("int", `key="1" id="3"`, "382"));
        assert(archive.data().containsXmlTag("int", `key="2" id="4"`, "283"));
        assert(archive.data().containsXmlTag("int", `key="3" id="5"`, "3820"));
        assert(archive.data().containsXmlTag("int", `key="4" id="6"`, "32"));
        assert(archive.data().containsXmlTag("int", `key="5" id="7"`, "832"));
    }
}

@describe("deserialize array")
{
    @it("should return a deserialize array equal to the original array") unittest
    {
        beforeEach();

        auto dDeserialized = serializer.deserialize!(D)(archive.untypedData);
        assert(d.arr == dDeserialized.arr);
    }
}