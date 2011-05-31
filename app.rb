require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'haml'
require 'datamapper'
require 'openssl'
require 'redis'
require 'proudhon'

require 'yaml'
require 'fileutils'
require 'uri'

require 'sinatra/jsonp'
require 'sinatra/session'
require 'sinatra/flash'
require 'sinatra/redirect_with_flash'
require 'redis-store'
require 'will_paginate'
require 'dm-paperclip'
require 'dm-paperclip/geometry'
require 'oembed_links'
require 'stalker'

## Config
config = YAML.load_file('config.yml')

## Config OEmbed
OEmbed.register_yaml_file(Dir.pwd + "/config-oembed.yml")

## Config Sinatra
use Rack::Session::Redis, :redis_server => config['redis']
set :site_title, config['site_title']
set :show_exceptions, TRUE
set :sessions, false
set :session_secret, "pomf=3"

## Config DataMapper
DataMapper.setup(:default, config['mysql'])

## Config Paperclip
Paperclip.configure do |conf|
  conf.root               = Dir.pwd
  conf.env                = 'development'
  conf.use_dm_validations = true
end

## Helpers
require 'helpers'

## Constants
ROOT = config['root']
REDIS = Redis.new :host => 'localhost', :port => 6379

## Models
require 'models'

DataMapper.finalize

if(config['migrate'])
  DataMapper.auto_migrate!
else
  DataMapper.auto_upgrade!
end

before do
  @cur_user = User.first(:id => session[:id]) if session?
  if session? and !@cur_user
    kill_session!
    redirect '/'
  end
end

## Controllers
require 'controllers'