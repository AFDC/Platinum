# AFDC League Management System
> This code is use by the Atlanta ultimate community (the [AFDC](http://www.afdc.com)) 
> to manage ultimate and goaltimate league registration and scheudling. 

[![Build Status][circleci-image]][circleci-url]

Platinum is a Ruby on Rails application used by the [Atlanta Flying Disc Club](http://www.afdc.com)
to manage league registrations, rosters, schedules, and result tracking. It is the latest evolution
of a platform that has been in use since before 2001. This application has been in development since 2013.

## Development setup

Platinum runs on [Docker](https://www.docker.com/) in both development and production. To get started,
you'll need a Docker client for your environment. They exist for most modern versions of Linux, 
[Mac](https://docs.docker.com/engine/installation/mac/), and 
[Windows](https://docs.docker.com/engine/installation/windows/). 

Once you've got Docker installed and the code checked out, running the system is as simple as running
the following command from the project root:

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

[circleci-image]: https://img.shields.io/circleci/project/github/AFDC/Platinum.svg
[circleci-url]: https://circleci.com/gh/AFDC/Platinum
