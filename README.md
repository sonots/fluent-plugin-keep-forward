# fluent-plugin-keep-forward [![Build Status](https://secure.travis-ci.org/sonots/fluent-plugin-keep-forward.png?branch=master)](http://travis-ci.org/sonots/fluent-plugin-keep-forward) [![Dependency Status](https://gemnasium.com/sonots/fluent-plugin-keep-forward.png)](https://gemnasium.com/sonots/fluent-plugin-keep-forward)

testing ruby: 1.9.2, 1.9.3, 2.0.0;  fluentd: 0.10.x

## About

This is an extension of fluentd out\_forward plugin to keep fowarding log data to the same node (as long as possible).

## Parameters

Basically same with out\_forward plugin. See http://docs.fluentd.org/articles/out_forward

Following parameters are additionally available: 

- keepalive (bool)

    Keepalive connection. Default is `false`.

- keepalive_time (time)

    Keepalive expired time. Default is nil (which means to keep connection as long as possible).

- heartbeat_type

    The transport protocol to use for heartbeats. The default is “udp”, but you can select “tcp” as well. 
    Furthermore, in keep_forward, you can also select "none" to disable heartbeat.

- keepforward

    `one` for keep forwarding all data to the one node.
    `tag` for keep forwarding data with the same tag to the same node.
    Default is `one`.

- prefer_recover (bool)

    Switch connection to a recovered node from standby nodes or less weighted nodes. Default is `true`.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new [Pull Request](../../pull/new/master)

## ChangeLog

See [CHANGELOG.md](CHANGELOG.md) for details.

## Copyright

Copyright (c) 2013 Naotoshi Seo. See [LICENSE](LICENSE) for details.
