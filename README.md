# Zeon

*Attention: this software is still under development. This is just a cental repository for contribution.*

**Zeon is a minimalist open-source federated message board**. It is written in Ruby using the Sinatra micro-framework, DataMapper and Redis. It aims to provide means of discussion between different websites and people, and to be lightweight, easy to install, easy to scale and easy to contribute.

Our strategy is to use caching and background workers to allow for non-blocking requests, serving a larger number of simultaneous users during peaks with a smaller setup.

The 'federated' part means that users on a certain Zeon instance can communicate with users on another instance. This is achieved using a protocol suite called OStatus, and it also allows us to communicate with other OStatus applications, including blogs and other social networks. For our OStatus needs we're using a gem called Proudhon.

## Dependencies

Software:

* A [Redis](http://redio.io) server for sessions and caching
* [Beanstalkd](http://kr.github.com/beanstalkd/) for queued jobs such as notifications, e-mails et cetera

Gems: We provide a Gemspec file, so all you need to get the ball rolling is to

    bundle install

## What it can do

* Users can post freetext, image, video and link posts
* Users can reply to them, like them
  * Federation: even if the posts are on another server
* Users can follow each other
  * Federation: even if the user followed is on another server
* Users have personalized home feeds
  * Federation: including posts from followed people on other servers

## Progress

* Creating of activities, replying, tagging, following, liking, browsing tags and other filtering are done
* Editing and deletion are not done
* Federation is not done