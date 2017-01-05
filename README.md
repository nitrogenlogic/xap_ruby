xap\_ruby
=========
This gem provides basic xAP Automation protocol support for EventMachine
applications.  It was developed for use in Nitrogen Logic controller software.
There are no automated tests and the code could be improved in many ways, but it
may still be useful to someone.

This is a Ruby library written from scratch for communicating with a home
automation network using the xAP protocol.  Supports sending and receiving
arbitrary xAP messages, triggering callbacks on certain received messages,
etc.  Also includes an implementation of an xAP Basic Status and Control
device.  Incoming xAP messages are parsed using an ad-hoc parser based on
Ruby's String#split() and Array#map() (a validating Treetop parser is also
available).  Network events are handled using EventMachine.

This library strives to support all address wildcard modes and data types
specified by the xAP specification as correctly as possible.

Read the examples under `test/` to understand how to create your own applications
using xap\_ruby.  All user-facing classes should have documenting comments.

xAP
---
xAP is a broadcast UDP protocol for interfacing disparate home automation
systems and devices.  Despite its weaknesses, xAP support is available for many
DIY and enthusiast automation systems.  For more information on xAP, visit
http://www.xapautomation.org/.

Installation
------------

Add this line to your application's Gemfile:

```ruby
gem 'xap_ruby'
```

Testing and Examples
--------------------
There are no automated tests.  You can test the code by running
test/bscdev\_test.rb to simulate an xAP BSC device, then running
test/xap\_receive.sh and test/xap\_query.sh on another machine.

* test/bsdev\_test.rb creates a dummy xAP Basic Status and Control device.
* test/parser\_test.rb tests the Treetop parser with a variety of xAP data types.
* test/xap\_query.sh uses netcat to send a network-wide xAP query message.
* test/xap\_receive.rb prints all xAP messages received from the network.

Users of xap\_ruby
------------------
Submit a pull request if you use this library somewhere and would like a
mention here.

* [Nitrogen Logic](http://www.nitrogenlogic.com/) - [Depth Camera Controller](http://www.nitrogenlogic.com/products/depth_controller.html)

Copyright
---------
(C)2012-2017 Mike Bourgeous (and any Git contributors), licensed under
two-clause BSD (see LICENSE)
