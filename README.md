# DCOB

This is a github bot to ensure every commit on a PR has the `Signed-off-by` attribution required by the [Developer Certificate of Origin](http://developercertificate.org/).

## Installation

Check out the source, run `bundle install`, then `bundle exec exe/dcob`.

## Configuration

The bot requires a toml configuration file with three settings:

```toml
[cfg]
login = "GITHUB_USERNAME"
access_token = "GITHUB_ACCESS_TOKEN"
secret_token = "SECRET_TOKEN"
```

The login is a github username; the access token is a personal access token
that has the Repo privilege. The secret token is the one you specify when you
add the bot as a webhook.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment. Run `bundle exec dcob` to use the gem
in this directory, ignoring other installed copies of this gem.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/habitat-sh/dcob. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

