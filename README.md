# DCOB

This is a github bot to ensure every commit on a PR has the `Signed-off-by` attribution required by the [Developer Certificate of Origin](http://developercertificate.org/).

## Installation

Check out the source, run `bundle install`, then `bundle exec exe/dcob`.

This is also easy to run on heroku; clone the repo, push it to heroku, set the environment variables and configure the webhook/access token. Viola!

## Configuration

The bot is written to support the 12Factor philosophy of configuration via
environment variables.

### _must_ be set in the environment:

* **RACK_ENV** :: set to `"production"` in production
* **SSL_CERT_FILE** :: path to a cacerts PEM file; there is one included in the
  dependencies of the bot, the path to which is available at `"$(hab pkg path core/cacerts)/ssl/certs/cacert.pem"`

### can be set in the environment or via toml files:

* **GITHUB_LOGIN** :: the username of the GitHub account through which the bot
  will take action
* **GITHUB_ACCESS_TOKEN** :: a personal access token for the GitHub user
  specified for login; the access token must have the following privileges:
    * `admin:repo_hook` to create webhooks on create or publicized repositories
    * `repo:status` to create statuses on commits in a repo
* **GITHUB_SECRET_TOKEN** :: [a shared secret for the GitHub
  webhooks](https://developer.github.com/webhooks/securing/) for authenticating
  incoming webhook payloads
* **DCO_INFO_URL** :: (optional) a URL to associate with a commit check result;
  defaults to a link to the text of the Developer Certificate of Origin itself,
  but we recommend setting this to link to a more detailed explanation of how
  your project uses the DCO and ways in which contributors can sign-off on their
  commits.

These settings can also be set from a toml config file, but note that the
environment variables take precedence. The advantage of configuring these
settings via toml is that the Habitat supervisor will detect when they are
changed and handle restarting the bot service to activate the new configuration.
The toml file format looks like:

```toml
[cfg]
login = "GITHUB_USERNAME"
access_token = "GITHUB_ACCESS_TOKEN"
secret_token = "SECRET_TOKEN"
dco_info_url = "https://a.webpage.explaining.what.the.dco.is/and.how.to.sign-off"
```

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

Bug reports and pull requests are welcome on GitHub at https://github.com/habitat-sh/dcob. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org/) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
