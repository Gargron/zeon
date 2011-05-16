require 'rubygems'
require 'sinatra'
require 'haml'
require 'datamapper'
require 'coffee-script'
require 'redis'

require 'sinatra/session'
require 'sinatra/flash'
require 'sinatra/redirect_with_flash'

DataMapper.setup(:default, 'mysql://root@localhost/zeon')

## Models
class User
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true, :unique => true, :index => true, :length => 4..20, :format => /^\w+$/i
  property :password, BCryptHash, :required => true, :length => 6..200
  property :email, String, :required => true, :unique => true, :format => :email_address
  property :status, Enum[ :active, :remote, :administrator, :inactive, :deleted ], :required => true, :default => :active
  property :private_key, Text
  property :public_key, Text
  property :updated_at, DateTime
  property :created_at, DateTime

  has n, :friendships
  has n, :follows, :model => 'Friendship', :child_key => :friend_id
  has n, :notifications
  has n, :activities

  has n, :follows, self, :through => :friendships, :via => :friend
  has n, :followers, self, :through => :follows, :via => :user
  has n, :tags, :through => Resource
  has n, :groups, :through => Resource

  def avatar(size = 30)
    "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(email)}?s=#{size}"
  end
end

class Friendship
  include DataMapper::Resource

  property :id, Serial
  property :accepted, Boolean, :default => false, :required => true
  property :updated_at, DateTime, :required => true
  property :created_at, DateTime, :required => true

  belongs_to :user
  belongs_to :friend, :model => 'User'
end

class Tag
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true, :unique => true, :index => true, :length => 1..50
  property :count, Integer, :required => true, :default => 1
  property :updated_at, DateTime, :required => true
  property :created_at, DateTime, :required => true

  has n, :activities
end

class Group
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true, :unique => true, :index => true, :length => 1..50
  property :description, Text
  property :count, Integer, :required => true, :default => 1
  property :updated_at, DateTime, :required => true
  property :created_at, DateTime, :required => true

  belongs_to :owner, :model => 'User'

  has n, :users, :through => Resource
  has n, :activities
end

class Activity
  include DataMapper::Resource

  property :id, Serial
  property :type, Enum[ :post, :reply, :comment, :link, :image,
    :video, :question, :event, :like, :bookmark, :vote, :tag,
    :attendance, :invitation, :poke, :recommendation, :message,
    :announcement ], :required => true
  property :title, String, :required => true
  property :content, Text
  property :meta, Json
  property :updated_at, DateTime, :required => true
  property :created_at, DateTime, :required => true

  belongs_to :user
  belongs_to :receiver, :model => 'User'
  belongs_to :activity
  belongs_to :group

  has n, :activities
  has n, :notifications
  has n, :tags, :through => Resource
end

class Notification
  include DataMapper::Resource

  property :id, Serial
  property :kind, Enum[ :announcement, :message, :mention, :activity,
    :mine, :bookmark, :replied, :subscription, :group ]
  property :created_at, DateTime, :required => true

  belongs_to :activity
  belongs_to :user
  belongs_to :sender, :model => 'User'
end

DataMapper.auto_upgrade!

before do
  @cur_user = User.first(:id => session[:id]) if session?
end

## Controllers
get '/' do
  haml :index
end

get '/style.css' do
  sass :style
end

get '/reset.css' do
  sass :reset
end

get '/script.js' do
  coffee :script
end

## Content pages
get '/dashboard' do
  session!

  haml :dashboard
end

# Login
get '/login' do
  redirect '/' if session?

  haml :'user/login'
end

post '/login.json' do
  halt 303 if session?

  if user = User.first(:name => params[:login], :status => [:active, :administrator]) and user.password == params[:password]
    session_start!
    session[:id], session[:name], session[:email] = user.id, user.name, user.email
    {:status => "ok"}.to_json
  else
    halt 303, {:error => "Wrong username/login combination"}.to_json
  end
end

post '/login' do
  redirect '/' if session?

  if user = User.first(:name => params[:login], :status => [:active, :administrator]) and user.password == params[:password]
    session_start!
    session[:id], session[:name], session[:email] = user.id, user.name, user.email
    redirect '/', :success => 'Login successful!'
  else
    flash.now[:error] = "Wrong username/login combination"
    haml :'user/login'
  end
end

# Sign Up
get '/signup' do
  redirect '/' if session?
  haml :'user/signup'
end

post '/signup.json' do
  halt 303, {:error => 'You\'re already logged on.'} if session?

  if user = User.create(:name => params[:login], :password => params[:password], :email => params[:email]) and user.saved?
    session_start!
    session[:id], session[:name], session[:email] = user.id, user.name, user.email
    {:status => "ok"}.to_json
  else
    halt 303, {:error => user.errors.to_a.join(' - ')}.to_json
  end
end

post '/signup' do
  redirect '/' if session?

  if user = User.create(:name => params[:login], :password => params[:password], :email => params[:email]) and user.saved?
    session_start!
    session[:id], session[:name], session[:email] = user.id, user.name, user.email
    redirect '/', :success => "Account #{user.name} successfully created!"
  else
    flash.now[:error] = user.errors.to_a.join(' - ')
  end

  haml :'user/signup'
end

# Reset password
get '/reset' do
  redirect '/' if session?

  haml :'user/reset'
end

post '/reset' do
  halt 303, {:error => 'You\'re already logged on.'} if session?

  if user = User.first(:email => params[:email])
    puts user.password = (rand(2**32) + 2**32).to_s(36)
    user.save
  end

  {:success => "If you're registered with us, your new password was just sent to your e-mail."}.to_json
end

post '/reset' do
  redirect '/' if session?

  if user = User.first(:email => params[:email])
    puts user.password = (rand(2**32) + 2**32).to_s(36)
    user.save
  end

  redirect '/', :success => "If you're registered with us, your new password was just sent to your e-mail."
end

# Edit Profile
get '/profile' do
  session!

  haml :'user/profile'
end

post '/profile.json' do
  halt 303, {:error => 'You\'re not logged.'} unless session?

  if @cur_user.password == params[:password]
    @cur_user.password = params[:new_password] unless params[:new_password].empty?
    @cur_user.email = params[:email]
    @cur_user.save

    {:status => "Successfully saved!"}.to_json
  else
    halt 303, {:error => "Wrong password!"}.to_json
  end
end

post '/profile' do
  session!

  if @cur_user.password == params[:password]
    @cur_user.password = params[:new_password]
    @cur_user.email = params[:email]
    @cur_user.save

    flash.now[:success] = "Successfully saved!"
    haml :'user/profile'
  else
    flash.now[:error] = "Wrong password!"
    haml :'user/profile'
  end
end

# Delete Profile
get '/profile/delete' do
  session!

  haml :'user/profile_delete'
end

post '/profile/delete' do
  session!

  if @cur_user.password == params[:password]
    @cur_user.status = :deleted
    @cur_user.save
    session_end!
    redirect '/', :success => "Your account was terminated."
  else
    flash.now[:error] = "Wrong password!"
  end

  haml :'user/profile_delete'
end

# Logout
get '/logout' do
  session_end!

  redirect '/', :success => 'You\'ve been logged out.'
end
