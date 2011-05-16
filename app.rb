require 'rubygems'
require 'sinatra'
require 'haml'
require 'datamapper'
require 'openssl'
require 'redis'
require 'proudhon'

require 'coffee-script'
require 'sinatra/jsonp'
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
  property :blob, Json
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

  before :create do
    key = OpenSSL::PKey::RSA::generate(512)
    self.private_key = key.to_s
    self.public_key = key.public_key.to_s
    self.blob = {} unless self.blob
  end
end

class Friendship
  include DataMapper::Resource

  property :id, Serial
  property :accepted, Boolean, :default => true, :required => true
  property :updated_at, DateTime
  property :created_at, DateTime

  belongs_to :user
  belongs_to :friend, :model => 'User'

  before :create do
    self.accepted = false if friend.blob[:private] == true
  end
end

class Tag
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true, :unique => true, :index => true, :length => 1..50
  property :count, Integer, :required => true, :default => 0
  property :type, Enum[ :normal, :toplevel, :blacklist ], :required => true, :default => :normal
  property :updated_at, DateTime
  property :created_at, DateTime

  has n, :activities
  has n, :users, :through => Resource
end

class Group
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true, :unique => true, :index => true, :length => 1..50
  property :description, Text
  property :count, Integer, :required => true, :default => 0
  property :updated_at, DateTime
  property :created_at, DateTime

  belongs_to :owner, :model => 'User'

  has n, :users, :through => Resource
  has n, :groups, :through => Resource
end

class Activity
  include DataMapper::Resource

  property :id, Serial
  property :type, Enum[ :post, :reply, :comment, :link, :image,
    :video, :question, :event, :like, :bookmark, :vote, :tag,
    :attendance, :invitation, :poke, :recommendation, :message,
    :announcement, :follow, :unfollow ], :required => true
  property :title, String, :required => true
  property :content, Text
  property :meta, Json
  property :updated_at, DateTime
  property :created_at, DateTime

  belongs_to :user
  belongs_to :activity
  belongs_to :group, :required => false

  has n, :activities
  has n, :notifications
  has n, :tags, :through => Resource

  CONTENT = [ :post, :reply, :comment, :link, :image, :video, :question, :event ]
  PRIVATE = [ :bookmark, :vote, :invitation, :poke, :reccomendation, :message ]
  MENTION = /@([a-z1-9]+)/i
  HASHTAG = /#([a-z1-9]+)/i
  GROUPTAG = /~([a-z1-9]+)/i

  before :save do
    if CONTENT.include? type
      # Parse mentions, tags and group-tags
      mentions = User.all(:name => content.scan(MENTION))
      tags = content.scan(HASHTAG).flatten.map {|t| Tag.first(:name => t) || Tag.create(:name => t)}
      group = Group.first(:name => content.scan(GROUPTAG))
    end
  end
end

class Notification
  include DataMapper::Resource

  property :id, Serial
  property :kind, Enum[ :announcement, :message, :mention, :activity,
    :mine, :bookmark, :replied, :tag, :group ]
  property :read, Boolean, :required => true, :default => false
  property :created_at, DateTime

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
  if session?
    haml :dashboard
  else
    haml :index
  end
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


## Content filter
post '/dashboard.json' do
  # Filter
end


## Content Interaction
post '/activity' do
  # Create Activity
end

post '/activitiy/:id/edit' do
  # Edit Activity
end

post '/activity/:id/delete' do
  # Delete Activity
end

post '/activity/:id/:action' do |id,action|
  # Reply
  # Like
  # Tag
  # Untag
  # Like
  # Unlike
  # Attend
  # Lock
  # Unlock
  # Bookmark
  # Unbookmark
  # Reccomend
  # Invite
end


## Profiles
get '/:user/?' do |user|
  # hCard Profile
end

get '/:user/feed/?' do |user|
  # Atom feed
end 


## Access Control
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

get '/logout' do
  session_end!

  redirect '/', :success => 'You\'ve been logged out.'
end
