/**
 * Copyright: Copyright (c) 2011-2013 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Aug 7, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module std.serialization.tests.subclass;

version (unittest):
private:

import std.serialization.serializer;
import std.serialization.archivers.xmlarchiver;
import std.serialization.tests.util;
import std.traits;

Serializer serializer;
XmlArchive!(char) archive;

class Base
{
    int a;
}

class Sub : Base
{
    int b;
}

Sub sub;

void beforeEach ()
{
    archive = new XmlArchive!(char);
    serializer = new Serializer(archive);

    sub = new Sub;
    sub.a = 3;
    sub.b = 4;

    serializer.serialize(sub);
}

@describe("serialize a subclass")
{
    @it("should return serialized subclass") unittest
    {
        beforeEach();

        assert(archive.data().containsDefaultXmlContent());
        assert(archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(Sub).toString() ~ `" type="` ~ fullyQualifiedName!(Sub) ~ `" key="0" id="0"`));
        assert(archive.data().containsXmlTag("int", `key="b" id="1"`, "4"));
        assert(archive.data().containsXmlTag("base", `type="` ~ fullyQualifiedName!(Base) ~ `" key="1" id="2"`));
        assert(archive.data().containsXmlTag("int", `key="a" id="3"`, "3"));
    }
}

@describe("deserialize class with a base class")
{
    @it("should return a deserialized string equal to the original string") unittest
    {
        beforeEach();

        auto subDeserialized = serializer.deserialize!(Sub)(archive.untypedData);

        assert(sub.a == subDeserialized.a);
        assert(sub.b == subDeserialized.b);
    }
}