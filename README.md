# Zeon

*Attention: this software is still under development. This is just a cental repository for contribution.*

**Zeon is a minimalist open-source federated message board**. It is written in Ruby using the Sinatra micro-framework, DataMapper and Redis. It aims to provide means of discussion between different websites and people, and to be lightweight, easy to install, easy to scale and easy to contribute.

Our strategy is to use caching and background workers to allow for non-blocking requests, serving a larger number of simultaneous users during peaks with a smaller setup.

The 'federated' part means that users on a certain Zeon instance can communicate with users on another instance. This is achieved using a protocol suite called OStatus, and it also allows us to communicate with other OStatus applications, including blogs and other social networks. For our OStatus needs we're using a gem called Proudhon.

## Configuration

You need to create a `config.yml` file in your app's directory. This is an example of the file:

    mysql: mysql://root@localhost/zeon
    redis: redis://localhost:6379/0
    root: domain.com
    site_title: Zeon
    env: development
    secret: verysecretphraseforsessions
    migrate: true
    chat: false

You also need to create a public/uploads folder and chmod it to 777 recursively for image uploads.

## Dependencies

Software:

* A [Redis](http://redio.io) server for sessions and caching
* [Beanstalkd](http://kr.github.com/beanstalkd/) for queued jobs such as notifications, e-mails et cetera
* ImageMagick

Gems: We provide a Gemspec file, so all you need to get the ball rolling is to

    bundle install

## What it can do (when it's ready)

* Users can post freetext, image, video and link posts
* Users can reply to them, like them
  * Federation: even if the posts are on another server
* Users can follow each other
  * Federation: even if the user followed is on another server
* Users have personalized home feeds
  * Federation: including posts from followed people on other servers

## Progress

* Creating of activities, replying, tagging, following, liking, browsing tags and other filtering are **done**
* Editing and deletion are **not done**
* Federation is **not done**
* Design of profiles is **not done**

## Other notes

* Currently the design for this is branded, a default neutral theme will be used instead when most of the project is finished
* The chat is an optional module and will be treated as such in the future (disabling/enabling)
  * The chat also requires a node.js server
  * And following npm modules:
    * socket.io
    * redis
* Any development help would be very appreciated

## Development

* Contribute if you can/want to, I will review your pull request and most likely accept
* Any help is appreciated
* As of now I am developing it alone
  * My gTalk is gargron [at] gmail.com and so is my MSN and e-mail