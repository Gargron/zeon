# Zeon

**Attention: this software is still under development. This is just a cental repository for contribution.**

Zeon is a minimalist open-source federated social network. It is written in Ruby using the Sinatra micro-framework, DataMapper and Redis. It aims to be lightweight, easy to install, easy to scale and easy to contribute.

Our strategy is to use caching and background workers to allow for non-blocking requests, serving a larger number of simultaneous users during peaks with a smaller setup.

The 'federated' part means that users on a certain Zeon instance can communicate with users on another instance. This is achieved using a protocol suite called OStatus, and it also allows us to communicate with other OStatus applications, including blogs and other social networks. For our OStatus needs we're using a gem called Proudhon.

## Dependencies

Those gems will get the ball rolling:

    sudo gem install sinatra haml will_paginate datamapper redis proudhon bcrypt yaml rspec sinatra-jsonp sinatra-session sinatra-flash sinatra-redirect-with-flash

Redis is our cache server. For Push support we use Comet. We recomend Thin, Unicorn, Rainbows!, or Phusion Passengers as your Ruby app server.

## How it works

Users are greeted with an activity stream. The user is free to choose what kinds of notifications will show up, like mentions, private messages, bumps, subscriptions or general friend activity. They can optionally browse public posts: the latest, the more popular, filter using tags or user names.

Activities also include content generation (posts, links, images, videos, polls and events), content interaction (replies and comments), social activity (like, vote, attend, reccomend, invite, bookmark and add tag) and private messages.