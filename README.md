Introduction
------------

The [ATEN iKVM][aten-ikvm], included on Supermicro motherboards, uses
a remote display protocol similar to VNC. This project is a reverse
engineered implementation of that protocol within the [Chicken][] VNC
viewer.

This work is currently a **proof of concept**, and is not suitable for
end users. It has been developed against a Supermicro X9SCM-iiF, other
devices may vary.

[aten-ikvm]: http://www.aten.co.nz/data/solution/IPMI/3-in-1.html
[Chicken]: http://chicken.sf.net

Protocol
--------

The protocol resembles VNC, but has additional bytes in most messages
and additional message types. The details of this protocol are encoded
in the [lens][].

The authentication packet is two 24-byte null terminated
strings. Either a username and password or a session ID from the web
interface can be used. For a session ID, the value is repeated in both
the username and password field.

The framebuffer format appears to be RGB555, despite the claims
otherwise in the pixel format sent as part of ServerInit. Updates
always encoded as raw bitmap data, and consist of either the entire
screen, or a list of 16x16 rectangles with coordinates. For the
implementation details of the image format, see the
[AtenEncodingReader][]. The rectangle included with the updates always
specifies the full display resolution, or when the screen is off, -640
by -480.

There are a number of additional messages, the meaning of which is
currently unknown. They do not seem to affect the connection and are
ignored entirely.

[lens]: https://github.com/thefloweringash/chicken-aten-ikvm/tree/master/lens
[AtenEncodingReader]: https://github.com/thefloweringash/chicken-aten-ikvm/blob/master/Source/AtenEncodingReader.m

Supported Features
------------------

 * Remote Display
 * Mouse
 * Keyboard

Missing features and todo
-------------------------

 * Username entry UI
 * Remote media

License
-------

Modifications are available under the same license as Chicken.
