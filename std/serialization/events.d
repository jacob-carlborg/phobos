/**
 * Copyright: Copyright (c) 2010-2013 Jacob Carlborg.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 26, 2010
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 *
 * Source: $(PHOBOSSRC std/serialization/_events.d)
 */
module std.serialization.events;

import std.serialization.attribute;

/**
 * Methods with this attribute attached will be called after the struct/class has been
 * deserialized.
 *
 * See_Also: $(LREF onSerialized)
 */
@attribute struct onDeserialized { }

/**
 * Methods with this attribute attached will be called before the struct/class has been
 * deserialized.
 *
 * See_Also: $(LREF onSerializing)
 */
@attribute struct onDeserializing { }

/**
 * Methods with this attribute attached will be called after the struct/class has been
 * serialized.
 *
 * See_Also: $(LREF onDeserialized)
 */
@attribute struct onSerialized { }

/**
 * Methods with this attribute attached will be called before the struct/class has been
 * serialized.
 *
 * See_Also: $(LREF onDeserializing)
 */
@attribute struct onSerializing { }