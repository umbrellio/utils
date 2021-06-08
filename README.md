# Umbrellio Utils [![Gem Version](https://badge.fury.io/rb/umbrellio-utils.svg)](https://badge.fury.io/rb/umbrellio-utils) [![Coverage Status](https://coveralls.io/repos/github/umbrellio/utils/badge.svg?branch=main)](https://coveralls.io/github/umbrellio/utils?branch=main)

## Installation

Add this line to your application's Gemfile:

```ruby
gem "umbrellio-utils"
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install umbrellio-utils
```

## Usage

### Quick Start

You can use modules and classes directly by accessing modules and classes
under namespace `UmbrellioUtils`. Or you can `include UmbrellioUtils` to other
module with name you like.

```ruby
# Direct using
UmbrellioUtils::Constants.get_class!(:object) #=> Object

# Aliasing to shorter name.

module Utils
  include UmbrellioUtils
end

Utils::Constants.get_class!(:object) #=> Object
Utils::Constants #=> UmbrellioUtils::Constants
```

### Configuration

Some modules and classes are configurable. Here's the full list of settings and what they do:

- `store_table_name` — table which is used by `UmbrellioUtils::Store` module.
  Defaults to `:store`
- `http_client_name` — fiber-local variable name for http client instance in
  `UmbrellioUtils::HTTPClient`. Defaults to `:application_httpclient`

You can change config in two ways. Firstly, you can change values by accessing configuration
directly. Secondly, you can use `UmbrellioUtils::configure` method which accepts a block.

```ruby

# First method

UmbrellioUtils.config.store_table_name = :cool_name

# Second method

module Utils
  include UmbrellioUtils

  configure do |config|
    config.store_table_name = :cool_name
  end
end
```

Keep in mind that the config is common to all modules: if you use multiple modules that include
`UmbrellioUtils`, then all modules will use the same configuration object.

### Extension

You can extend module with you own project specific methods
via `UmbrellioUtils::extend_util!`.

```ruby
module Utils
  include UmbrellioUtils

  configure do |config|
    config.store_table_name = :cool_name
  end

  extend_util!(:Constants) do
    def useful_method
      "Just string"
    end
  end
end

Utils::Constants.useful_method #=> "Just string"
```

Or you can define methods in your module and then extend the desired module.

```ruby
module MyHelpers
  def useful_method
    "Just string"
  end
end

module Utils
  include UmbrellioUtils

  extend_util!(:Constants) { extend MyHelpers }
end

Utils::Constants.useful_method #=> "Just string"
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/umbrellio/utils.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Authors

Created by Umbrellio's Ruby developers

<a href="https://github.com/umbrellio/">
<img style="float: left;" src="https://umbrellio.github.io/Umbrellio/supported_by_umbrellio.svg" alt="Supported by Umbrellio" width="439" height="72">
</a>
