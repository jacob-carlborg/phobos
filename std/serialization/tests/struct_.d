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
import std.serialization.archives.xmlarchive;
import std.serialization.tests.util;
import std.traits;

Serializer serializer;
XmlArchive!(char) archive;

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
    archive = new XmlArchive!(char);
	serializer = new Serializer(archive);

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