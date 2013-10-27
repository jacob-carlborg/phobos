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

mixin template ConfigMixin ()
{
    /**
     * Indicates if the archiver should pretty format the data.
     *
     * Example:
     * If set to false the data will be formatted as below:
     * <foo>bar</foo>
     *
     * Example:
     * If set to true data will be formatted as below:
     * <foo>
     *     bar
     * </foo>
     *
     * See_Also: indentation
     */
    enum prettyFormat = true;

    /**
     * The number spaces used for indentation.
     *
     * Ignore if prettyFormat is false.
     *
     * Example:
     * If set to 2
     * ---
     * <foo>
     *   bar
     * </foo>
     * ---
     *
     * Example:
     * If set to 4
     * ---
     * <foo>
     *     bar
     * </foo>
     * ---
     *
     * See_Also: prettyFormat
     * See_Also: indentationString
     */
    enum indentation = 4;

    /**
     * Indicates if a root tag should be included.
     *
     * Example:
     * If set to true:
     * ---
     * <archive version="1.0.0" type="std.xml">
     *     <foo>
     *         bar
     *     </foo>
     * </archive>
     * ---
     *
     * Example:
     * If set to false:
     * ---
     * <foo>
     *     bar
     * </foo>
     * ---
     */
    enum rootTag = true;

    /**
     * Indicates that an XML declaration should be included.
     *
     * Example:
     * If set to true:
     * ---
     * <?xml version="1.0" encoding="UTF-8"?>
     * <foo>
     *     bar
     * </foo>
     * ---
     *
     * Example:
     * If set to false:
     * ---
     * <foo>
     *     bar
     * </foo>
     * ---
     */
    enum xmlDeclaration = true;
}

struct Config
{
    mixin ConfigMixin;
}

package:

mixin template XmlArchiverMixin (Config)
{
    /// The version of the archiver.
    enum version_ = "1.0.0";

    /// The config of the archiver.
    alias config = Config;

private:

    enum archiverType = "std.serialization.archivers.xmlarchiver.XmlArchiver";
    enum xmlDeclaration = `<?xml version="1.0" encoding="UTF-8"?>`;
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