# Hansa

Detect the programming language based only on content.

Just content, no filename, no extension, nothing else. There
are other tools for that.

This is a port of a piece of [go-enry](https://github.com/go-enry/go-enry)
to Crystal, trained on the same Linguist corpus (go-enry v2.9.6).

Before the classifier runs, two content-only strategies from go-enry
v2 are consulted, in this order:

1. Editor modelines (`# vim: set ft=ruby:`, `# -*- mode: python -*-`)
   in the first or last 5 lines.
2. Shebang lines, including `/usr/bin/env` indirection, with the
   interpreter mapped through Linguist's table. A shebang naming one
   language wins outright; ambiguous ones (perl → Perl/Pod) restrict
   the classifier to those candidates.

Paradoxically it will detect Crystal as Ruby but it's close enough ;-)

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     hansa:
       github: ralsina/hansa
   ```

2. Run `shards install`

## Usage

```crystal
require "hansa"

puts Hansa.classify(File.read(ARGV[0]))   # => "Ruby"
```

There is a "hansa" command line tool that can be used to classify files:

```
$ hansa src/hansa.cr
src/hansa.cr CoffeeScript

$ printf '#!/bin/bash\necho hi\n' | hansa -
- Shell
```

Run `hansa --help` for usage. Errors are reported on stderr with a
non-zero exit code, and a file argument of `-` reads standard input.

## Development

I don't expect to do much more development here.

## Contributing

1. Fork it (<https://github.com/ralsina/hansa/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Roberto Alsina](https://github.com/ralsina) - creator and maintainer
