require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'haml'
require 'sass'
require 'datamapper'
require 'openssl'
require 'proudhon'

require 'yaml'
require 'fileutils'
require 'open-uri'
require 'uri'
require 'rest_client'
require 'nokogiri'
require 'logger'
require 'json'
require 'sinatra/session'
require 'rack-flash'
require 'sinatra/redirect_with_flash'
require 'will_paginate'
require 'dm-paperclip'
require 'dm-paperclip/geometry'
require 'oembed_links'
require 'stalker'
require 'redcarpet'

## Config
config = YAML.load_file('config/config.yml')

## Config OEmbed
OEmbed.register_yaml_file(Dir.pwd + "/config/config-oembed.yml")

## Config Sinatra
set :site_title, config['site_title']
set :environment, config['env']
set :show_exceptions, true if config['env'] == 'development'
set :reload_templates, true if config['env'] == 'development'
set :session_secret, config['secret']
set :views, Proc.new { File.join(root, "app/views") }
#set :logging, true
set :run, false

use Rack::Flash, :sweep => true

#log = File.new("app.log", "a")
#STDOUT.reopen(log)
#STDERR.reopen(log)

Tilt.register 'markdown', Tilt::RedcarpetTemplate

## Config DataMapper
DataMapper.setup(:default, config['mysql'])

## Config Paperclip
Paperclip.configure do |conf|
  conf.root               = Dir.pwd
  conf.env                = config['env']
  conf.use_dm_validations = true
end

## Helpers
require 'app/helpers'

## Constants
ROOT = config['root']

## Models
require 'app/models'

DataMapper.finalize

if(config['migrate'])
  DataMapper.auto_migrate!
else
  DataMapper.auto_upgrade!
end

before do
  @cur_user = User.first(:id => session[:id]) if session?
  if session? and !@cur_user
    session_end!
    redirect '/'
  end
end

## Controllers
require 'app/controllers'