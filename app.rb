require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'haml'
require 'datamapper'
require 'openssl'
require 'redis'
require 'proudhon'

require 'yaml'

require 'sinatra/jsonp'
require 'sinatra/session'
require 'sinatra/flash'
require 'sinatra/redirect_with_flash'
require 'will_paginate'

config = YAML.load_file('config.yml')

set :site_title, config['site_title']
set :show_exceptions, TRUE
DataMapper.setup(:default, config['mysql'])

## Models
class User
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true, :unique => true, :index => true, :length => 1..30, :format => /^\w+$/i
  property :password, BCryptHash, :required => true, :length => 6..200
  property :email, String, :required => true, :unique => true, :format => :email_address
  property :status, Enum[ :active, :remote, :administrator, :inactive, :deleted ], :required => true, :default => :active
  property :blob, Json
  property :private_key, Text
  property :public_key, Text
  property :updated_at, DateTime
  property :created_at, DateTime

  has n, :friendships
  has n, :friendships2, :model => 'Friendship', :child_key => :friend_id
  has n, :notifications
  has n, :activities

  has n, :follows, self, :through => :friendships, :via => :friend
  has n, :followers, self, :through => :friendships2, :via => :user
  has n, :tags, :through => Resource, :constraint => :destroy
  has n, :groups, :through => Resource, :constraint => :destroy

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

  has n, :activities, :through => Resource, :constraint => :destroy
  has n, :users, :through => Resource, :constraint => :destroy
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

  has n, :activities
  has n, :users, :through => Resource, :constraint => :destroy
end

class Activity
  include DataMapper::Resource

  property :id, Serial
  property :type, Enum[ :post, :reply, :comment, :link, :image,
    :video, :question, :event, :like, :bookmark, :vote, :tag,
    :attendance, :invitation, :poke, :recommendation, :message,
    :announcement, :follow, :unfollow ], :required => true, :index => true
  property :title, String
  property :content, Text
  property :meta, Json, :default => {}
  property :updated_at, DateTime
  property :created_at, DateTime

  belongs_to :user
  belongs_to :parent, :model => 'Activity', :required => false
  belongs_to :group, :required => false

  has n, :children, :model => 'Activity', :child_key => [ :parent_id ]
  has n, :notifications
  has n, :tags, :through => Resource, :constraint => :destroy

  validates_presence_of :title, :if => lambda { |t| NEW_CONTENT.include? t.type }

  ## Constants
  NEW_CONTENT = [ :post, :link, :video, :question, :event ]
  CONTENT = [ :post, :reply, :comment, :link, :image, :video, :question, :event ]
  REPLY = [ :reply, :comment ]
  SPECIFIC = [ :follow, :unfollow, :like, :vote, :tag, :attendance ]
  PRIVATE = [ :bookmark, :vote, :invitation, :poke, :recommendation, :message ]
  MENTION = /@([a-z1-9]+)/i
  HASHTAG = /#([a-z1-9]+)/i
  GROUPTAG = /~([a-z1-9]+)/i

  ## Callbacks
  after :create do
    # Denormalize
    if NEW_CONTENT.include? self.type
      self.meta = { :post_count => 1, :like_count => 0, :bumped_id => self.id, :bumped_by => self.user.name, :bumped_at => self.created_at }
      self.save
    end
    # Update parent's denormalization
    if REPLY.include? self.type
      new_meta = { :post_count => self.parent.meta[:post_count] + 1, :bumped_id => self.id, :bumped_by => self.user.name, :bumped_at => self.created_at }
      self.parent.meta.merge(new_meta)
      self.parent.save
    end
    unless PRIVATE.include? self.type
      mentions = User.all(:name => content.scan(MENTION))
      self.tags = content.scan(HASHTAG).flatten.map {|t| Tag.first(:name => t) || Tag.create(:name => t) }
      self.group = Group.first(:name => content.scan(GROUPTAG))
      self.save

      root = self.parent || self
      notify(:mention, mentions)
      notify(:group, root.group.users) if root.group
      notify(:tag, root.tags.users)
      notify(:activity, self.user.friendships2.all(:accepted => true).users)
      notify(:mine, [ root.user ])
      notify(:bookmark, root.children(:type => :bookmark).users)
      notify(:replied, root.children(:type => :reply).users)
      notify(:liked, root.children(:type => :like).users)
    end
  end

  def self.public
      all(:type => CONTENT, :parent_id => nil)
  end

  def notify(kind, users)
    users.each do |target|
      self.notifications << Notification.create(:kind => kind, :user => target, :sender => self.user, :activity => self, :parent => self.parent || self)
    end
  end
end

class Notification
  include DataMapper::Resource

  property :id, Serial
  property :kind, Enum[ :announcement, :message, :mention, :activity,
    :mine, :bookmark, :replied, :liked, :tag, :group ]
  property :read, Boolean, :required => true, :default => false
  property :created_at, DateTime

  belongs_to :activity
  belongs_to :parent, :model => 'Activity'
  belongs_to :user
  belongs_to :sender, :model => 'User'

  after :create do
    # Dispatch to e-mail, salmon, etc
  end
end

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

helpers do
  def will_paginate(collection)
    total_pages, current_page = collection.total_pages, collection.current_page
    prev = nil
    gap_marker = '&hellip;'
    inner_window, outer_window = 4, 1
    window_from = current_page - inner_window
    window_to = current_page + inner_window
    @links = []

    return nil unless total_pages > 1

    if window_to > total_pages
      window_from -= window_to - total_pages
      window_to = total_pages
    end
    if window_from < 1
      window_to += 1 - window_from
      window_from = 1
      window_to = total_pages if window_to > total_pages
    end

    visible   = (1..total_pages).to_a
    left_gap  = (2 + outer_window)...window_from
    right_gap = (window_to + 1)...(total_pages - outer_window)
    visible  -= left_gap.to_a  if left_gap.last - left_gap.first > 1
    visible  -= right_gap.to_a if right_gap.last - right_gap.first > 1

    visible.inject [] do |links, n|
      links << {:text => gap_marker, :link => false, :active => false} if prev and n > prev + 1
      links << {:text => n, :link => n != current_page ? true : false, :active => n != current_page ? false : true}
      prev = n
      @links = links
    end

    haml :"helpers/pagination"
  end

  def ago(time)
    diff = Time.now - Time.parse(time.to_s)
    ranges = { :second => 1..59, :minute => 60..3559, :hour => 3600..86399,
      :day => 86400..2592000, :month => 2592000..31104000, :year => 31104000..999999999 }

    return 'just now' if diff < 5

    ranges.collect do |n,r|
      "#{(diff/r.first).ceil} #{n}#{'s' if (diff/r.first).ceil > 1} ago" if r.include? diff
    end.join
  end
end

## Controllers
get '/' do
  if session?
    redirect '/home'
  else
    redirect '/all'
  end
end

get %r{/all(/sort:([popular|latest|oldest|updated|posts]+))?(/page/([\d]+))?} do |o1, s, o2, p|
  sort = { :order => :id.desc }
  if s == "latest"
    sort = { :order => :id.desc }
  end
  if s == "oldest"
    sort = { :order => :id.asc }
  end
  if s == "updated"
    #sort = { :order => :meta.bumped_at.desc }
  end
  if s == "posts"
    #sort = { :order => :meta.count.desc }
  end
  @posts = Activity.public.all( sort ).paginate( :page => p, :per_page => 20 )

  haml :index
end

get %r{/home(/page/([\d]+))?} do |o, p|
  session!

  @activity = @cur_user.notifications.activities(:order => :id.desc).paginate({ :page => p, :per_page => 20})

  haml :dashboard
end

get %r{/thread/([\d]+)(/page/([\d]+))?} do |id, o, p|
  @conversation = Activity.all( :conditions => ["id = ? or parent_id = ?", id, id], :order => :id.asc ).paginate({ :page => p, :per_page => 20})

  haml :thread
end

get '/style/style.css' do
  sass :"sass/style", :load_paths => [ File.dirname(__FILE__) + '/views' ]
end


## Content filter
post '/dashboard.json' do
  # Filter
end


## Content Interaction
post '/activity' do
  # Create Activity
end

post '/activitiy/:id/edit' do |id|
  # Edit Activity
end

post '/activity/:id/delete' do |id|
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
get '/user/:user/?' do |user|
  # hCard Profile
end

get '/user/:user/feed/?' do |user|
  # Atom feed
end


## Access Control
get '/login' do
  redirect '/' if session?

  haml :'user/login'
end

post '/login.json' do
  halt 303 if session?

  if user = User.first(:name => params[:name], :status => [:active, :administrator]) and user.password == params[:password]
    session_start!
    session[:id], session[:name], session[:email] = user.id, user.name, user.email
    {:status => "ok"}.to_json
  else
    halt 303, {:error => "Wrong username/login combination"}.to_json
  end
end

post '/login' do
  redirect '/' if session?

  if user = User.first(:name => params[:name], :status => [:active, :administrator]) and user.password == params[:password]
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

  if user = User.create(:name => params[:name], :password => params[:password], :email => params[:email]) and user.saved?
    session_start!
    session[:id], session[:name], session[:email] = user.id, user.name, user.email
    {:status => "ok"}.to_json
  else
    halt 303, {:error => user.errors.to_a.join(' - ')}.to_json
  end
end

post '/signup' do
  redirect '/' if session?

  if user = User.create(:name => params[:name], :password => params[:password], :email => params[:email]) and user.saved?
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