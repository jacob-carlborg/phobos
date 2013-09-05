/**
 * Copyright: Copyright (c) 2013-2013 Jacob Carlborg. All rights reserved.
 * Authors: Juan Manuel
 * Version: Initial created: Apr 14, 2013
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module std.serialization.tests.enumconstantmember;

version (unittest):
private:

import std.serialization.serializer;
import std.serialization.archivers.xmlarchiver;
import std.serialization.tests.util;
import std.traits;

Serializer serializer;
XmlArchive!(char) archive;

class G
{
    int a;
    enum int someConstant = 4 * 1024;
}

G g;

void beforeEach ()
{
    archive = new XmlArchive!(char);
    serializer = new Serializer(archive);

    g = new G;
    g.a = 123;

    serializer.serialize(g);
}

@describe("serialize enum")
{
    @it("shouldn't fail to compile when there is a constant enum member") unittest
    {
        beforeEach();

        assert(archive.data().containsDefaultXmlContent());
        assert(archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(G).toString() ~ `" type="` ~ fullyQualifiedName!(G) ~ `" key="0" id="0"`));
        assert(archive.data().containsXmlTag("int", `key="a" id="1"`, "123"));
    }
}

@describe("deserialize enum")
{
    @it("shouldn't fail to deserialize when there is a constant enum member") unittest
    {
        auto gDeserialized = serializer.deserialize!(G)(archive.untypedData);
        assert(g.a == gDeserialized.a);
    }
}