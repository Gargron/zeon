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
require 'will_paginate'
require 'dm-paperclip'
require 'dm-paperclip/geometry'
require 'oembed_links'

config = YAML.load_file('config.yml')
OEmbed.register_yaml_file(Dir.pwd + "/config-oembed.yml")

set :site_title, config['site_title']
set :show_exceptions, TRUE
DataMapper.setup(:default, config['mysql'])

Paperclip.configure do |conf|
  conf.root               = Dir.pwd
  conf.env                = 'development'
  conf.use_dm_validations = true
end

## Models
class User
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true, :unique => true, :index => true, :length => 1..30, :format => /^\w+$/i
  property :password, BCryptHash, :required => true, :length => 6..200
  property :email, String, :required => true, :unique => true, :format => :email_address
  property :status, Enum[ :active, :remote, :administrator, :inactive, :deleted ], :required => true, :default => :active
  property :blob, Json, :default => {}
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
  include DataMapper::Validate
  include Paperclip::Resource

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

  has_attached_file :image,
                    :path => Dir.pwd + '/public/uploads/:attachment/:id/:style/:filename',
                    :url => '/uploads/:attachment/:id/:style/:filename',
                    :styles => { :thumb_all => '200x150>', :thumb_dash => '220x240>', :medium => '600x1000>' }

  property :image_dimensions, String

  validates_presence_of :title, :if => lambda { |t| REQ_TITLE.include? t.type }

  validates_attachment_presence :image, :if => lambda { |t| t.type == :image }
  validates_attachment_content_type :image, :content_type => [ "image/png", "image/jpg", "image/jpeg", "image/gif" ]
  validates_attachment_size :image, :in => 1..5242880

  ## Constants
  REQ_TITLE = [ :post, :link, :video, :question, :event ]
  NEW_CONTENT = [ :post, :image, :link, :video, :question, :event ]
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
      self.meta = meta.merge( "post_count" => 1, "like_count" => 0, "bumped_id" => self.id, "bumped_by" => self.user.name, "bumped_at" => self.created_at )
      self.save
    end
    # Update parent's denormalization
    if REPLY.include? self.type
      self.parent.meta = parent.meta.merge( "post_count" => parent.meta.fetch("post_count", 1) + 1, "bumped_id" => self.id, "bumped_by" => self.user.name, "bumped_at" => DateTime.now )
      self.parent.updated_at = DateTime.now
      self.parent.save
    end
    if self.type == :like
      self.parent.meta = parent.meta.merge( "like_count" => parent.meta.fetch("like_count", 0) + 1 )
      self.parent.save
    end
    unless PRIVATE.include? self.type
      root = self.parent || self

      unless self.content.nil?
        mentions = User.all(:name => content.scan(MENTION))
        self.tags = content.scan(HASHTAG).flatten.map {|t| Tag.first(:name => t) || Tag.create(:name => t) }
        self.group = Group.first(:name => content.scan(GROUPTAG))
        self.save

        notify(:mention, mentions)
        notify(:group, root.group.users) if root.group
        notify(:tag, root.tags.users)
      end

      notify(:activity, self.user.friendships2.all(:accepted => true).users)
      notify(:mine, [ root.user ])
      notify(:bookmark, root.children(:type => :bookmark).users)
      notify(:replied, root.children(:type => :reply).users)
      notify(:liked, root.children(:type => :like).users)
    end
  end

  def self.public
      all(:type => NEW_CONTENT, :parent_id => nil)
  end

  def add_tags(spaced_tags)
    unless spaced_tags.empty?
      spaced_tags = spaced_tags.scan(/[\w\s!\(\)\&\+_-]/).join
      tags = spaced_tags.downcase.split(" ")
      self.tags = tags.flatten.map { |t| Tag.first(:name => t) || Tag.create(:name => t) }
      self.save
    end
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

class OEmbed
  def self.valid?(url, *attribs)
    unless (vschemes = @schemes.select { |a| url =~ a[0] }).empty?
      regex, provider = vschemes.first
      data = get_url_for_provider(url, provider, *attribs)
      if data.keys.empty?
        false
      else
        response = OEmbed::Response.new(provider, url, data)
        response
      end
    else
      false
    end
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

  def goto(parent_id, post_id, per_page)
    count = Activity.first(:id => parent_id).children(:type => :reply, :id.lt => post_id).count
    page  = (count / per_page).floor + 1
    if page == 1
      "/thread/" + parent_id.to_s + "#p" + post_id.to_s
    else
      "/thread/" + parent_id.to_s + "/page/" + page.to_s + "#p" + post_id.to_s
    end
  end

  def paper_mash(file_hash)
    mash = Hash.new
    mash['tempfile'] = file_hash[:tempfile]
    mash['filename'] = file_hash[:filename]
    mash['content_type'] = file_hash[:type]
    mash['size'] = file_hash[:tempfile].size
    mash
  end

  def make_bytes(bytes, max_digits=3)
    k = 2.0**10
    m = 2.0**20
    g = 2.0**30
    t = 2.0**40
    value, suffix, precision = case bytes
      when 0...k
        [ bytes, 'b', 0 ]
      else
        value, suffix = case bytes
          when k...m : [ bytes / k, 'kB' ]
          when m...g : [ bytes / m, 'MB' ]
          when g...t : [ bytes / g, 'GB' ]
          else         [ bytes / t, 'TB' ]
        end
        used_digits = case value
          when   0...10   : 1
          when  10...100  : 2
          when 100...1000 : 3
        end
        leftover_digits = max_digits - used_digits
        [ value, suffix, leftover_digits > 0 ? leftover_digits : 0 ]
    end
    "%.#{precision}f#{suffix}" % value
  end

  def megapixels(string)
    dimensions = string.split("x")
    width  = dimensions[0]
    height = dimensions[1]
    mp     = (width.to_f * height.to_f) / 1000000.0
    mp     = (mp * 10).round / 10.0
    mp
  end

  def ellipse_url(url, length = 30)
    url = url.gsub(/http:\/\/(www\.)?/, "")
    if url.length >= length
      url1 = url[0..(length / 2)]
      url2 = url[-(length / 2)..-1]
      url1 + "&hellip;" + url2
    else
      url
    end
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

get %r{/all(/sort:([popular|latest|oldest|updated]+))?(/page/([\d]+))?} do |o1, s, o2, p|
  sort = { :order => :id.desc }

  if s == "latest"
    sort = { :order => :id.desc }
  end
  if s == "oldest"
    sort = { :order => :id.asc }
  end
  if s == "updated"
    sort = { :order => :updated_at.desc }
  end

  @posts = Activity.public.all( sort ).paginate( :page => p, :per_page => 15 )

  @f_posts = []
  last_image = nil
  image_i = 0

  @posts.each do |a|
    if a.type == :image
      if image_i == 0
        @f_posts.push a
        last_image = @f_posts.index a
        image_i += 1
      else
        posts1 = @f_posts[0..last_image]
        posts2 = @f_posts[(last_image+1)..-1]
        posts1.push a
        @f_posts = posts1.concat(posts2)
        last_image = @f_posts.index a
        if(image_i < 2)
          image_i += 1
        else
          image_i = 0
        end
      end
    else
      @f_posts.push a
    end
  end
  haml :index
end

get %r{/home(/page/([\d]+))?} do |o, p|
  session!

  @activity = @cur_user.notifications.activities(:order => :id.desc).paginate({ :page => p, :per_page => 10})

  haml :dashboard
end

get %r{/thread/([\d]+)(/page/([\d]+))?} do |id, o, p|
  @item = Activity.first( :id => id, :parent_id => nil )
  if @item.nil?
    halt 404
  end
  @conversation = Activity.all( :conditions => ["id = ? or parent_id = ?", id, id], :order => :id.asc ).paginate({ :page => p, :per_page => 20})
  haml :thread
end

get '/create' do
  session!

  haml :create
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
  session!
  # Create Activity
  type = params[:type]

  case type
  when "post"
    if !params[:title].empty? and !params[:text].empty?
      if freetext = Activity.create( :title => params[:title], :type => :post, :content => params[:text], :user => @cur_user ) and freetext.saved?
        freetext.add_tags(params[:tags])
        redirect '/thread/' + freetext.id.to_s
      else
        redirect '/create', :error => freetext.errors.to_a.join(' - ')
      end
    else
      redirect '/create', :error => "A freetext post requires a title and the text itself!"
    end
  when "image"
    unless params[:image_file]
      redirect '/create', :error => "An image post requires an actual file to be uploaded!"
    end
    # Create image
    unless params[:url].empty? or !(params[:url] =~ URI::regexp).nil?
      redirect '/create', :error => "The source URL you entered wasn't a URL. Either input a real one or none at all."
    end
    dimensions = Paperclip::Geometry.from_file(params[:image_file][:tempfile])
    if image = Activity.create( :type => :image, :user => @cur_user, :content => params[:text], :meta => params[:url].empty? ? {} : { :source_url => params[:url] }, :image => paper_mash(params[:image_file]), :image_dimensions => dimensions.width.round.to_s + "x" + dimensions.height.round.to_s ) and image.saved?
      image.add_tags(params[:tags])
      redirect '/thread/' + image.id.to_s
    else
      redirect '/create', :error => image.errors.to_a.join(' - ')
    end
  when "video"
    if !params[:title].empty? and !params[:url].empty?
      if (params[:url] =~ URI::regexp).nil?
        redirect '/create', :error => "That 'URL' you got there wasn't a valid URL!"
      end
      video_html = nil
      if (oembed = OEmbed.valid? params[:url])
        video_html = oembed.to_s
      else
        redirect '/create', :error => "Sorry, we currently support only Youtube, Vimeo, Hulu and Viddler"
      end
      if video = Activity.create( :type => :video, :user => @cur_user, :title => params[:title], :content => params[:text], :meta => { :video_url => params[:url], :video_html => video_html } ) and video.saved?
        video.add_tags(params[:tags])
        redirect '/thread/' + video.id.to_s
      else
        redirect '/create', :error => video.errors.to_a.join(' - ')
      end
    else
      redirect '/create', :error => "A video post requires a title and a URL!"
    end
  when "link"
    if !params[:url].empty? and !params[:title].empty?
      # Create link
      if !(params[:url] =~ URI::regexp).nil?
        if link = Activity.create( :type => :link, :user => @cur_user, :title => params[:title], :content => params[:text], :meta => { :url => params[:url] } ) and link.saved?
          link.add_tags(params[:tags])
          redirect '/thread/' + link.id.to_s
        else
          redirect '/create', :error => link.errors.to_a.join(' - ')
        end
      else
        redirect '/create', :error => "The URL you entered wasn't a valid URL."
      end
    else
      redirect '/create', :error => "A link post requires the link itself and a title"
    end
  else
    redirect '/create'
  end
end

post '/activitiy/:id/edit' do |id|
  # Edit Activity
end

post '/activity/:id/delete' do |id|
  # Delete Activity
end

post '/activity/:id/:action' do |id,action|
  # Reply
  if !session?
    if !params[:username].empty? and !params[:password].empty?
      if user = User.first(:name => params[:username], :status => [:active, :administrator]) and user.password == params[:password]
        session_start!
        session[:id], session[:name], session[:email] = user.id, user.name, user.email
        do_it = true
      else
        redirect '/thread/' + id.to_s + "#reply", :error => "Your username or password or both are wrong"
      end
    elsif !params[:new_username].empty? and !params[:new_email].empty? and !params[:new_password].empty?
      if user = User.create(:name => params[:new_username], :password => params[:new_password], :email => params[:new_email]) and user.saved?
        session_start!
        session[:id], session[:name], session[:email] = user.id, user.name, user.email
        do_it = true
      else
        redirect '/thread/' + id.to_s + "#reply", :error => user.errors.to_a.join(' - ')
      end
    else
      redirect '/thread/' + id.to_s + "#reply", :error => "Not signed in at all, please either input login or registration data"
    end
  end
  if action == "reply"
    if session? or do_it
      user = User.first(:id => session[:id])
      parent = Activity.first( :id => id, :parent_id => nil )
      halt 404 unless parent
      if reply = Activity.create( :parent_id => id, :user => user, :type => :reply, :content => params[:content]) and reply.saved?
        redirect goto(id, reply.id, 20)
      end
    end
  end
  # Like
  if action == "like"
    session!
    if like = Activity.create( :parent_id => id, :user => @cur_user, :type => :like) and like.saved?
      redirect '/thread/' + id.to_s
    end
  end
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
  redirect '/' if session?

  if params[:email].length < 1
    redirect '/reset', :error => "E-mail must not be blank"
  end

  if user = User.first(:email => params[:email])
    puts user.password = (rand(2**32) + 2**32).to_s(36)
    user.save
  end

  redirect '/reset', :success => "If you're registered with us, your new password was just sent to your e-mail."
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