# manageiq-providers-hawkular

[![Gem Version](https://badge.fury.io/rb/manageiq-providers-hawkular.svg)](http://badge.fury.io/rb/manageiq-providers-hawkular)
[![Build Status](https://travis-ci.org/ManageIQ/manageiq-providers-hawkular.svg)](https://travis-ci.org/ManageIQ/manageiq-providers-hawkular)
[![Code Climate](https://codeclimate.com/github/ManageIQ/manageiq-providers-hawkular.svg)](https://codeclimate.com/github/ManageIQ/manageiq-providers-hawkular)
[![Test Coverage](https://codeclimate.com/github/ManageIQ/manageiq-providers-hawkular/badges/coverage.svg)](https://codeclimate.com/github/ManageIQ/manageiq-providers-hawkular/coverage)
[![Dependency Status](https://gemnasium.com/ManageIQ/manageiq-providers-hawkular.svg)](https://gemnasium.com/ManageIQ/manageiq-providers-hawkular)
[![Security](https://hakiri.io/github/ManageIQ/manageiq-providers-hawkular/master.svg)](https://hakiri.io/github/ManageIQ/manageiq-providers-hawkular/master)

[![Chat](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/ManageIQ/manageiq-providers-hawkular?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Translate](https://img.shields.io/badge/translate-zanata-blue.svg)](https://translate.zanata.org/zanata/project/view/manageiq-providers-hawkular)

ManageIQ plugin for the Hawkular provider.

## Development

This is a quick guide outlining all the necessary steps to get ManageIQ up and
running for development.

### Dependencies

* Ruby 2.3+ (Ruby 2.4.1 recommended)
* Bundler 1.15.3+
* PostgreSQL 9.5+
* Memcached
* Node/npm and the usual suspects: Bower, Yarn, Gulp, Webpack
* Docker
* 16gb RAM (8gb or less is doable, but not recommended)

Any Linux/OS X System is compatible, as far as we are concerned.

For system configuration, please refer to here: http://manageiq.org/docs/guides/developer_setup

### Cloning and configuring the application

The first necessary step is to fork the following repositories:

* [ManageIQ Core](https://github.com/ManageIQ/manageiq)
* [ManageIQ UI Classic](https://github.com/ManageIQ/manageiq-ui-classic)
* [ManageIQ Schema](https://github.com/ManageIQ/manageiq-schema)
* [ManageIQ API](https://github.com/ManageIQ/manageiq-api)
* [ManageIQ Hawkular Provider](https://github.com/ManageIQ/manageiq-providers-hawkular)
* [Hawkular Ruby Client](https://github.com/hawkular/hawkular-client-ruby)

Then, we clone them:

```bash
mkdir ~/ManageIQ && cd ~/ManageIQ
git clone git@github.com:<your-username>/manageiq
git clone git@github.com:<your-username>/manageiq-ui-classic
git clone git@github.com:<your-username>/manageiq-schema
git clone git@github.com:<your-username>/manageiq-api
git clone git@github.com:<your-username>/manageiq-providers-hawkular
git clone git@github.com:<your-username>/hawkular-client-ruby
```

And then we add the upstream remotes to fetch changes on the main codebase:

```bash
cd ~/ManageIQ/manageiq
git remote add upstream git@github.com:ManageIQ/manageiq
cd ..

cd manageiq-ui-classic
git remote add upstream git@github.com:ManageIQ/manageiq-ui-classic
cd ..

cd manageiq-schema
git remote add upstream git@github.com:ManageIQ/manageiq-schema
cd ..

cd manageiq-api
git remote add upstream git@github.com:ManageIQ/manageiq-api
cd ..

cd manageiq-providers-hawkular
git remote add upstream git@github.com:ManageIQ/manageiq-providers-hawkular
cd ..

cd hawkular-client-ruby
git remote add upstream git@github.com:hawkular/hawkular-client-ruby
cd ..
```

Now we need to make ManageIQ use our vendored repositories instead of the local
clone it does with Bundler. Create a file on `bundler.d` on the core repository
called `vendor.rb` (any name is OK, but we're going for consistency here).

This file is our addition to the Gemfile where we can override some gems and
add some other development dependencies without messing with the main
repository. Its contents are the following:

```ruby
override_gem name, path: File.expand_path("../../manageiq", __dir__)
override_gem name, path: File.expand_path("../../manageiq-ui-classic", __dir__)
override_gem name, path: File.expand_path("../../manageiq-schema", __dir__)
override_gem name, path: File.expand_path("../../manageiq-api", __dir__)
override_gem name, path: File.expand_path("../../manageiq-providers-hawkular", __dir__)
```

We also recommend some other dependencies that might come in hand for debugging:

```ruby
gem 'pry'
gem 'pry-byebug'
```

The next step is to configure each repository:

```bash
cd ~/ManageIQ/manageiq
./bin/setup
cd ..

cd manageiq-ui-classic
./bin/setup
cd ..

cd manageiq-schema
./bin/setup
cd ..

cd manageiq-api
./bin/setup
cd ..

cd manageiq-providers-hawkular
./bin/setup
cd ..

cd hawkular-client-ruby
bundle install
cd ..
```

This should be enough. To run the application, we can run this, which will run the application on background on port 3000:

```bash
bundle exec rake evm:start
```

Then, we can visit `http://localhost:3000` and sign in. If everything is working fine, you should see this:

![](https://i.imgur.com/mtW7UHK.png)

Sign in with the default credentials (`admin`/`smartvm`), and you should be good to go!

### Updating the repositories

To update the repositories, you need to go on each one and run `bin/update`. This script takes care of it:

```bash
#!/bin/bash

MIQ_DIR="$HOME/manageiq"
OLD_PWD="$(pwd)"

cd $MIQ_DIR

for repo in $(find $MIQ_DIR -maxdepth 1 -type d)
do
  echo "Updating repo $repo..."

  cd $repo

  if [ -d .git ]; then
    git fetch -a
    git pull --rebase upstream master
    ./bin/update
    cd -
  fi
done

echo "Updating core..."

cd $MIQ_DIR/core

./bin/update

cd $OLD_PWD

echo "DONE."
```

## Installing Hawkular

There are two ways of installing Hawkular: manually or via Docker. There are
use cases for both, and you can mix and match for your needs, but the simplest
way of getting it working is via Hawkinit, which downloads, configures and runs
the hawkular server, and 0+ wildfly instances with the Hawkular agent installed
and configured.

#### Via Docker (recommended)

First, we need to install [hawkinit](https://github.com/Jiri-Kremser/hawkinit),
a CLI tool that takes care of running a Hawkular cluster for you. You can do
that by getting it through npm, like this:

```bash
sudo npm install -g hawkinit
```

You'll also need to have Docker installed, and your group should be on the
`docker` group:

```bash
sudo usermod -a -G docker `whoami`
newgrp docker # to update your groups on the session
```

Then, by running `hawkinit`, you'll see something like this:

![](https://i.imgur.com/cYZ3iLb.png)

It will ask then some questions:

* What should it use for running the services? Docker-Compose? Openshift?
* What version of Hawkular?
* What version of Cassandra?
* What WildFly version?
* Standalone or Domain mode for Wildfly?
* How many WildFly servers?

For most options, the default is ok, and is the fastest way to have something
running. One important thing is that when you run hawkinit again, it will not
reuse the same images, but use new ones. If that's not the behaviour you want,
you can find the generated `docker-compose.yml` on `/tmp`.

#### Manually

TODO.

### Adding Hawkular as an a Provider

Now we're going to add Hawkular as an Provider to ManageIQ. To do that, first
we need to have Hawkular running, which we did on the last section. We're also
going to assume we used `hawkinit` to start the server. While that's not a
problem, custom setups might require custom configuration, so tread
accordingly.

So, with ManageIQ running, go to `http://localhost:3000`, sign in, and go on
the sidebar menu to `Middleware -> Providers`. At that screen we're going to
add a new provider, like this:

![](https://i.imgur.com/OOVL75A.png)

And on the next screen, we're going to set it up like this:

![](https://i.imgur.com/sGBJM5f.png)

* Name: Doesn't matter
* Type: Hawkular
* Security Protocol: Non-SSL
* Hostname: localhost
* API Port: 8080
* Username: jdoe
* Password: password

Press the `Validate` button, and then the `Add` button in case everything goes
well with the validation, and you'll be able to see this:

![](https://i.imgur.com/sGBJM5f.png)

It might take a while to fetch everything on the inventory from Hawkular. If
that doesn't happen automatically, you might have to do the refreshing
manually, by going on the provider page and clicking this:

![](https://i.imgur.com/iDRFHcY.png)

### Further Reading and References

* ManageIQ Developer Setup: [http://manageiq.org/docs/guides/developer_setup](http://manageiq.org/docs/guides/developer_setup)
* ManageIQ Plugins Setup: [http://manageiq.org/docs/guides/developer_setup/plugins](http://manageiq.org/docs/guides/developer_setup/plugins)
* Hawkular Installation Guide: [http://www.hawkular.org/hawkular-services/docs/installation-guide/](http://www.hawkular.org/hawkular-services/docs/installation-guide/)
* Hawkinit: [http://github.com/hawkular/hawkinit](http://github.com/hawkular/hawkinit)
* HawkFX (to see the inventory): [https://github.com/pilhuhn/hawkfx](https://github.com/pilhuhn/hawkfx)
* Example WAR for deployment: [https://github.com/mtho11/hawkular-testing/blob/master/ticket-monster.war](https://github.com/mtho11/hawkular-testing/blob/master/ticket-monster.war)
* Example JDBC Driver jars:
  * [https://github.com/mtho11/hawkular-testing/blob/master/postgresql-9.4.1212.jre6.jar](https://github.com/mtho11/hawkular-testing/blob/master/postgresql-9.4.1212.jre6.jar)
  * [https://github.com/mtho11/hawkular-testing/blob/master/mysql-connector-java-5.1.41.zip](https://github.com/mtho11/hawkular-testing/blob/master/mysql-connector-java-5.1.41.zip)

## License

The gem is available as open source under the terms of the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
