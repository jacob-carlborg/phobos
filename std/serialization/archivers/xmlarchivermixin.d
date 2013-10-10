/**
 * Copyright: Copyright (c) 2010-2013 Jacob Carlborg.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 26, 2010
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 *
 * Source: $(PHOBOSSRC std/serialization/archivers/_xmlarchivermixin.d)
 */
module std.serialization.archivers.xmlarchivermixin;

import std.serialization.archivers.archiver;
import std.string : format;

package:

mixin template XmlArchiverMixin ()
{
    /// The version of the archiver.
    enum version_ = "1.0.0";

private:

    enum archiverType = "std.serialization.archivers.xmlarchiver.XmlArchiver";
    enum xmlTag = `<?xml version="1.0" encoding="UTF-8"?>`;
    enum header = format(`<archive version="%s" type="%s">`, version_, archiverType);
    enum footer = "</archive>";

    struct Tags
    {
        static enum Data structTag = "struct";
        static enum Data dataTag = "data";
        static enum Data archiveTag = "archive";
        static enum Data arrayTag = "array";
        static enum Data objectTag = "object";
        static enum Data baseTag = "base";
        static enum Data stringTag = "string";
        static enum Data referenceTag = "reference";
        static enum Data pointerTag = "pointer";
        static enum Data associativeArrayTag = "associativeArray";
        static enum Data typedefTag = "typedef";
        static enum Data nullTag = "null";
        static enum Data enumTag = "enum";
        static enum Data sliceTag = "slice";
        static enum Data elementTag = "element";
        static enum Data keyTag = "key";
        static enum Data valueTag = "value";
        static enum Data rangeTag = "range";
    }

    struct Attributes
    {
        static enum Data invalidAttribute = "\0";
        static enum Data typeAttribute = "type";
        static enum Data versionAttribute = "version";
        static enum Data lengthAttribute = "length";
        static enum Data keyAttribute = "key";
        static enum Data runtimeTypeAttribute = "runtimeType";
        static enum Data idAttribute = "id";
        static enum Data keyTypeAttribute = "keyType";
        static enum Data valueTypeAttribute = "valueType";
        static enum Data offsetAttribute = "offset";
        static enum Data baseTypeAttribute = "baseType";
    }

    struct Node
    {
        XmlDocument.Node parent;
        XmlDocument.Node node;
        Id id;
        string key;
    }
}