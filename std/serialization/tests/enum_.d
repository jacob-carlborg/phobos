/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Aug 6, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module std.serialization.tests.enum_;

version (unittest):
private:

import std.serialization.serializer;
import std.serialization.archives.xmlarchive;
import std.serialization.tests.util;
import std.traits;

Serializer serializer;
XmlArchive!(char) archive;

enum Foo
{
	a,
	b,
	c
}

class G
{
	Foo foo;
}

G g;

void beforeEach ()
{
    archive = new XmlArchive!(char);
	serializer = new Serializer(archive);

	g = new G;
	g.foo = Foo.b;

	serializer.serialize(g);
}

@describe("serialize enum")
{
	@it("should return a serialized enum") unittest
	{
	    beforeEach();

		assert(archive.data().containsDefaultXmlContent());
		assert(archive.data().containsXmlTag("object", `runtimeType="` ~ typeid(G).toString() ~ `" type="` ~ fullyQualifiedName!(G) ~ `" key="0" id="0"`));
		assert(archive.data().containsXmlTag("enum", `type="` ~ typeid(Foo).toString() ~ `" baseType="int" key="foo" id="1"`, "1"));
	}
}

@describe("deserialize enum")
{
	@it("should return an enum equal to the original enum") unittest
	{
	    beforeEach();

		auto gDeserialized = serializer.deserialize!(G)(archive.untypedData);
		assert(g.foo == gDeserialized.foo);
	}
}