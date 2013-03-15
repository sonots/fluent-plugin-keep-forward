# fluent-plugin-keep-forward [![Build Status](https://secure.travis-ci.org/sonots/fluent-plugin-keep-forward.png?branch=master)](http://travis-ci.org/sonots/fluent-plugin-keep-forward) [![Dependency Status](https://gemnasium.com/sonots/fluent-plugin-keep-forward.png)](https://gemnasium.com/sonots/fluent-plugin-keep-forward)

testing ruby: 1.9.2, 1.9.3, 2.0.0;  fluentd: 0.10.x

## About

This is an extension of fluentd out\_forward plugin to keep fowarding log data to the same node (as much as possible).

## Configuration

Exactly same with out\_forward plugin. See http://docs.fluentd.org/articles/out_forward

## Log

This plugin outputs log messages like

    $ grep 'keep forwarding' /var/log/td-agent/td-agent.log
    2013-03-15 10:35:06 +0900: keep forwarding tag 'fluent.info' to node 'localhost:24224' host="localhost" port=24224 weight=60

You can tell the address of forwarding node easily. 

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new [Pull Request](../../pull/new/master)

## Copyright

Copyright (c) 2013 Naotoshi SEO. See [LICENSE](LICENSE) for details.
