/**
 * Copyright: Copyright (c) 2011-2013 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Aug 7, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module std.serialization.tests.events;

version (unittest):
private:

import std.serialization.serializer;
import std.serialization.events;
import std.serialization.archives.xmlarchive;
import std.serialization.tests.util;
import std.traits;

Serializer serializer;
XmlArchive!(char) archive;

int b;
int c;

class Events
{
    int a;
    int d;

    @onSerializing void serializing ()
    {
        a = 3;
    }

    @onSerialized void serialized ()
    {
        b = 4;
    }

    @onDeserializing void deserializing ()
    {
        c = 5;
    }

    @onDeserialized void deserialized ()
    {
        d = 6;
    }
}

Events events;

void beforeEach ()
{
    archive = new XmlArchive!(char);
    serializer = new Serializer(archive);

    events = new Events;

    serializer.serialize(events);
}

@describe("serialize a class with event handlers")
{
    @it("should return serialized class with the correct values set by the event handlers") unittest
    {
        beforeEach();

        assert(archive.data().containsDefaultXmlContent());
        assert(archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(Events).toString() ~ `" type="` ~ fullyQualifiedName!(Events) ~ `" key="0" id="0"`));

        assert(archive.data().containsXmlTag("int", `key="a" id="1"`, "3"));
        assert(archive.data().containsXmlTag("int", `key="d" id="2"`, "0"));

        assert(b == 4);
    }
}

@describe("deserialize a class with event handlers")
{
    @it("should return deserialized class with the correct values set by the event handlers") unittest
    {
        beforeEach();

        auto eventsDeserialized = serializer.deserialize!(Events)(archive.untypedData);

        assert(eventsDeserialized.a == 3);
        assert(eventsDeserialized.d == 6);

        assert(c == 5);
    }
}