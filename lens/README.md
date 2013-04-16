This directory contains a "binary-lens" which is able to decode both
sides of a VNC session to the ATEN iKVM.

Ideally this is a simple executable specification, but due to the
relative lack of polish on the lens library, it may serve simply as a
debugging tool.

Typical usage
--------------

    $ tcpdump -s 0 -w ikvm.pcap 'host ikvm-host'
    # ... start a new session ...
    # ... generate interesting traffic ...
    ^C
    $ tcpflow -r ikvm.pcap
    $ ruby lens.rb read-client < 010.000.000.001.12345-010.000.000.002.05900 \
        > client.decode
    $ ruby lens.rb read-server < 010.000.000.002.05900-010.000.000.001.12345 \
        > server.decode

License
-------
BSD 2-clause
