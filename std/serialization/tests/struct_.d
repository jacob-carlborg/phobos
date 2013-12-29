/**
 * Copyright: Copyright (c) 2011-2013 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Aug 6, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module std.serialization.tests.struct_;

version (unittest):
private:

import std.serialization.serializer;
import std.serialization.archivers.xmlarchiver;
import std.serialization.tests.util;
import std.traits;

alias Archiver = XmlArchiver!();
Archiver archive;
Serializer!(Archiver) serializer;

struct B
{
    bool opEquals (ref const B) const
    {
        return true;
    }
}

B b;

void beforeEach ()
{
    import std.array : appender;

    archive = new Archiver(appender!(string)());
    serializer = Serializer(archive);

    serializer.serialize(B());
}

@describe("serialize struct")
{
    @it("should return a serialized struct") unittest
    {
        beforeEach();

        assert(archive.data().containsDefaultXmlContent());
        assert(archive.data().containsXmlTag("struct", `type="` ~ fullyQualifiedName!(B) ~ `" key="0" id="0"`, true));
    }
}

@describe("deserialize struct")
{
    @it("should return a deserialized struct equal to the original struct") unittest
    {
        beforeEach();

        auto bDeserialized = serializer.deserialize!(B)(archive.untypedData);
        assert(b == bDeserialized);
    }
}