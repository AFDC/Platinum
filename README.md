# AFDC League Management System
> This code is use by the Atlanta ultimate community (the [AFDC](http://www.afdc.com)) 
> to manage ultimate and goaltimate league registration and scheudling. 

[![Build Status][circleci-image]][circleci-url] [![View performance data on Skylight](https://badges.skylight.io/status/pZMk9YMLIt2z.svg)](https://oss.skylight.io/app/applications/pZMk9YMLIt2z)

[![View performance data on Skylight](https://badges.skylight.io/rpm/pZMk9YMLIt2z.svg)](https://oss.skylight.io/app/applications/pZMk9YMLIt2z) [![View performance data on Skylight](https://badges.skylight.io/typical/pZMk9YMLIt2z.svg)](https://oss.skylight.io/app/applications/pZMk9YMLIt2z) [![View performance data on Skylight](https://badges.skylight.io/typical/pZMk9YMLIt2z.svg)](https://oss.skylight.io/app/applications/pZMk9YMLIt2z)

Platinum is a Ruby on Rails application used by the [Atlanta Flying Disc Club](http://www.afdc.com) to manage league registrations, rosters, schedules, and result tracking. It is the latest evolution of a platform that has been in use since before 2001. This application has been in development since 2013.

## Development setup

Platinum runs on [Docker](https://www.docker.com/) in both development and production. To get started, you'll need a Docker client for your environment. They exist for most modern versions of [Linux](https://docs.docker.com/glossary/?term=installation), [Mac](https://docs.docker.com/engine/installation/mac/), and  [Windows](https://docs.docker.com/engine/installation/windows/). 

Once you've got Docker installed next step is to copy the contents of the sample.env file(present in the root directory of the repo) to .env. After that,running the system is as simple as running the following command from the project root:

```sh
docker-compose up
```

You should then be able to visit [http://localhost:3000/](http://localhost:3000/) and see the AFDC's
site running on your computer.

In development, mail sent from the system will captured and available via mailhog at 
[http://localhost:8025/](http://localhost:8025/).

## Meta

Maintained by Pete Holiday – pete.holiday@gmail.com

Distributed under the MIT license. See ``LICENSE`` for more information.

Contributors agree to be bound by [Contributor Covenant v1.4.0](http://contributor-covenant.org/version/1/4/code_of_conduct.txt)

[circleci-image]: https://img.shields.io/circleci/project/github/AFDC/Platinum.svg
[circleci-url]: https://circleci.com/gh/AFDC/Platinum
