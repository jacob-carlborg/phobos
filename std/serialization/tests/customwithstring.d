/**
 * Copyright: Copyright (c) 2013-2013 Jacob Carlborg. All rights reserved.
 * Authors: Juan Manuel
 * Version: Initial created: Apr 14, 2013
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module std.serialization.tests.customwithstring;

version (unittest):
private:

import std.serialization.serializer;
import std.serialization.archives.xmlarchive;
import std.serialization.tests.util;
import std.traits;

Serializer serializer;
XmlArchive!(char) archive;

class Foo
{
    int a;
    string b;

    void toData (Serializer serializer, Serializer.Data key)
    {
        i++;
        serializer.serialize(a, "x");
        serializer.serialize(b, "y");
    }

    void fromData (Serializer serializer, Serializer.Data key)
    {
        i++;
        a = serializer.deserialize!(int)("x");
        b = serializer.deserialize!(string)("y");
    }
}

Foo foo;
int i;

void beforeEach ()
{
    archive = new XmlArchive!(char);
    serializer = new Serializer(archive);

    foo = new Foo;
    foo.a = 3;
    foo.b = "a string";
    i = 3;

    serializer.serialize(foo);
}

@describe("serialize object using custom serialization methods")
{
    @it("should return a custom serialized object") unittest
    {
        beforeEach();

        assert(archive.data().containsDefaultXmlContent());
        assert(archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(Foo).toString() ~ `" type="` ~ fullyQualifiedName!(Foo) ~ `" key="0" id="0"`));
        assert(archive.data().containsXmlTag("int", `key="x" id="1"`));
        assert(archive.data().containsXmlTag("string", `type="immutable(char)" length="8" key="y" id="2"`));

        assert(i == 4);
    }
}

@describe("deserialize object using custom serialization methods")
{
    @it("should deserialize the string field properly") unittest
    {
        beforeEach();

        auto f = serializer.deserialize!(Foo)(archive.untypedData);

        assert(foo.a == f.a);
        assert(foo.b == f.b);

        assert(i == 5);
    }
}