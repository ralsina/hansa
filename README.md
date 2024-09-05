# Hansa

Detect the programming language based only on content.

Just content, no filename, no extension, nothing else. There
are other tools for that.

This is a port of a piece of [go-enry](https://github.com/go-enry/go-enry)
to Crystal.

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
