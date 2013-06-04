# fluent-plugin-keep-forward [![Build Status](https://secure.travis-ci.org/sonots/fluent-plugin-keep-forward.png?branch=master)](http://travis-ci.org/sonots/fluent-plugin-keep-forward) [![Dependency Status](https://gemnasium.com/sonots/fluent-plugin-keep-forward.png)](https://gemnasium.com/sonots/fluent-plugin-keep-forward)

testing ruby: 1.9.2, 1.9.3, 2.0.0;  fluentd: 0.10.x

## About

This is an extension of fluentd out\_forward plugin to keep fowarding log data to the same node (as much as possible).

## Parameters

Basically same with out\_forward plugin. See http://docs.fluentd.org/articles/out_forward

Following parameters are additionally available: 

- prefer_recover

    Switch connection to a recovered node from standby nodes or less weighted nodes. Default is `true`.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new [Pull Request](../../pull/new/master)

## Copyright

Copyright (c) 2013 Naotoshi SEO. See [LICENSE](LICENSE) for details.
