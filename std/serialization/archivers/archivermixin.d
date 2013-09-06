/**
 * Copyright: Copyright (c) 2010-2013 Jacob Carlborg.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 26, 2010
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 *
 * Source: $(PHOBOSSRC std/serialization/archivers/_archivermixin.d)
 */
module std.serialization.archivers.archivermixin;

mixin template ArchiverMixin ()
{   
    /// The type of an ID.
    alias size_t Id;

    /// The typed used to represent the archived data in an untyped form.
    alias immutable(void)[] UntypedData;

    /**
     * This is the type of an error callback which is called when an unexpected event occurs.
     *
     * Params:
     *     exception = the exception indicating what error occurred
     *     data = arbitrary data pass along, deprecated
     *
     * See_Also: $(LREF errorCallback)
     */
    alias void delegate (SerializationException exception) ErrorCallback;

    /**
     * This callback will be called when an unexpected event occurs, i.e. an expected element
     * is missing in the unarchiving process.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * serializer.errorCallback = (SerializationException exception) {
     *     writeln(exception);
     *     throw exception;
     * };
     * ---
     *
     * See_Also: $(LREF ErrorCallback)
     */
    @property ErrorCallback errorCallback ();

    /**
     * This callback will be called when an unexpected event occurs, i.e. an expected element
     * is missing in the unarchiving process.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * serializer.errorCallback = (SerializationException exception) {
     *     writeln(exception);
     *     throw exception;
     * };
     * ---
     *
     * See_Also: $(LREF ErrorCallback)
     */
    @property ErrorCallback errorCallback (ErrorCallback errorCallback);
}

mixin template ArchiverBaseMixin ()
{
    /// The typed used to represent the archived data in a typed form.
    alias immutable(U)[] Data;

    private ErrorCallback errorCallback_;

    /**
     * This callback will be called when an unexpected event occurs, i.e. an expected element
     * is missing in the unarchiving process.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * serializer.errorCallback = (SerializationException exception) {
     *     writeln(exception);
     *     throw exception;
     * };
     * ---
     */
    @property ErrorCallback errorCallback ()
    {
        return errorCallback_;
    }

    /**
     * This callback will be called when an unexpected event occurs, i.e. an expected element
     * is missing in the unarchiving process.
     *
     * Examples:
     * ---
     * auto archive = new XmlArchive!();
     * serializer.errorCallback = (SerializationException exception) {
     *     writeln(exception);
     *     throw exception;
     * };
     * ---
     */
    @property ErrorCallback errorCallback (ErrorCallback errorCallback)
    {
        return errorCallback_ = errorCallback;
    }

    /**
     * Creates a new instance of this class with an error callback
     *
     * Params:
     *     errorCallback = the error callback used for ths instance
     */
    protected this (ErrorCallback errorCallback)
    {
        this.errorCallback = errorCallback;
    }

    /**
     * Converts the given value into the type used for archiving.
     *
     * Examples:
     * ---
     * auto i = toData(3);
     * assert(i == "3");
     * ---
     *
     * Params:
     *     value = the value to convert
     *
     * Returns: the converted value
     *
     * Throws: SerializationException if the conversion failed
     * See_Also: $(LREF fromData)
     * See_Also: $(LREF floatingPointToData)
     */
    protected Data toData (T) (T value)
    {
        try
        {
            static if (isFloatingPoint!(T))
                return floatingPointToData(value);

            else
                return to!(Data)(value);
        }

        catch (ConvException e)
        {
            error(e);
            return Data.init;
        }
    }
}