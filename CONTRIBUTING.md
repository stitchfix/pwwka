# Contributing
Thanks for using and improving *pwwka*! If you'd like to help out, check out [the project's issues list](https://github.com/stitchfix/pwwka/issues) for ideas on what could be improved.

We're actively using Pwwka in production here at [Stitch Fix](http://technology.stitchfix.com/) and look forward to seeing Pwwka grow and improve with your help. Contributions are warmly welcomed.

If there's an idea you'd like to propose, or a design change, feel free to file a new issue or send a pull request:

1. [Fork][fork] the repo.
1. [Create a topic branch.][branch]
1. Write tests.
1. Implement your feature or fix bug.
1. Add, commit, and push your changes.
1. [Submit a pull request.][pr]

[fork]: https://help.github.com/articles/fork-a-repo/
[branch]: https://help.github.com/articles/creating-and-deleting-branches-within-your-repository/
[pr]: https://help.github.com/articles/using-pull-requests/

## General Guidelines

* When in doubt, test it.  If you can't test it, re-think what you are doing.
* Code formatting and internal application architecture should be consistent.

## Testing

The tests assume that:

* Rabbit is running on port 10001
* Redis is running on port 10003

You can achieve this by using Docker and running `docker-compose up` in the root of this directory.  If you don't want to use Docker,
that's fine.  You'll need to set `PWWKA_RESQUE_REDIS_PORT` and `PWWKA_RABBIT_PORT` in your environment to the ports where those services
are running.

Tests in `spec/integration` are end-to-end tests that use Rabbita and attempt to assert behavior from the point of view of the application
owner.  If you write tests here, depend on as few of Pwwka's internals as possible, and *no mocking of anything*.

Tests in `spec/unit` are more traditional unit tests and *should not require Rabbit or Redis* to be running.
