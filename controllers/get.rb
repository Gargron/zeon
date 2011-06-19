get '/' do
  if session?
    redirect '/home'
  else
    redirect '/all'
  end
end

get %r{/all(/type:[post|image|link|video]+)?(/tags:[\w!&+~-]+)?(/[creator|poster]+:[\w]+)?(/sort:[popular|latest|oldest|updated|neglected]+)?(/page/[\d]+)?} do |r_type, r_tags, r_user, r_sort, r_page|
  # Defaults
  default = { :type => [:post, :image, :link, :video], :parent_id => nil, :order => :id.desc }

  # Sorting
  case r_sort.to_s.gsub(/\/sort:/, "")
  when "latest"
    default[:order] = :id.desc
  when "oldest"
    default[:order] = :id.asc
  when "updated"
    default[:order] = :updated_at.desc
  when "neglected"
    default[:order] = :updated_at.asc
  end

  # Select only by user
  r_user = r_user.to_s.gsub(/\//, "").split(":")

  case r_user[0]
  when "creator"
    default[:user] = { :name => r_user[1] }
  when "poster"
    default[:user] = { :name => r_user[1] }
  end

  # Select only by type
  case r_type.to_s.gsub(/\/type:/, "")
  when "post"
    default[:type] = :post
  when "image"
    default[:type] = :image
  when "link"
    default[:type] = :link
  when "video"
    default[:type] = :video
  end

  @filter = default[:type].to_s unless r_type.nil?

  # Pagination
  unless (page = r_page.to_s.gsub(/\/page\//, "").to_i) and page > 0
    page = 1
  end

  # Select by tags
  tags = r_tags.to_s.gsub(/\/tags:/, "")
  all_tags = tags.split(/\+~-/)

  include_tags = []
  exclude_tags = []
  maybe_tags = []

  # Parse tag query
  tags.scan(/([+|\-|~])?([\w&!]+)/i) { |op, tag|
    if op.nil? or op == '+'
      include_tags.push tag
    elsif op == '-'
      exclude_tags.push tag
    elsif op == '~'
      maybe_tags.push tag
    end
  }

  if all_tags.length > 0 && all_tags.length <= 7
    @title = "Tagged " + all_tags.to_a.join(", ")
    @posts = ((Tag.all( :name => include_tags).activities( default ) - Tag.all( :name => exclude_tags).activities( default )) | Tag.all( :name => maybe_tags).activities( default )).paginate( :page => page, :per_page => 15 )
  else
    @title = @filter ? "All #{@filter}s" : nil
    @posts = Activity.all( default ).paginate( :page => page, :per_page => 15 )
  end

  @f_posts = []
  last_image = nil
  image_i = 0

  @posts.reverse!.each do |a|
    if a.type == :image
      if image_i == 0
        @f_posts.push a
        last_image = @f_posts.index a
        image_i += 1
      else
        @f_posts.insert last_image, a
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
  @f_posts = @f_posts.reverse!
  haml :index
end

get %r{/home(/inbox)?(/page/[\d]+)?} do |inbox, r_page|
  session!

  unless (page = r_page.to_s.gsub(/\/page\//, "").to_i) and page > 0
    page = 1
  end

  @inbox = true unless inbox.nil?

  @title = @inbox ? "Inbox" : "Dashboard"

  @activity = @cur_user.notifications( :kind => inbox.nil? ? [ :activity, :mine, :replied, :liked, :tag, :group] : [ :message, :mention ] ).activities( :order => :id.desc ).paginate( :page => page, :per_page => 10 )
  haml :dashboard
end

get %r{/thread/([\d]+)(/page/([\d]+))?} do |id, o, p|
  @item = Activity.first( :id => id, :parent_id => nil )
  if @item.nil?
    halt 404
  end
  @title = @item.title || "#" + @item.id.to_s
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

get '/follow' do
  haml :"user/follow"
end

## Profiles
get '/user/:user/?' do |user|
  @user = User.first( :name => user, :domain => ROOT )

  unless @user
    halt 404
  end

  haml :"profile"
end

get '/user/:user/feed/?' do |user|
  # Atom feed
  @user = User.first( :name => user )
  halt 404 unless @user
  @entries = Activity.all( :type => [:post, :image, :video, :link], :parent_id => nil, :user => @user, :order => :id.desc )
  content_type 'application/atom+xml'
  haml :"user/feed", :layout => false
end

get '/webfinger/?' do
  r_user = params[:id].to_s.gsub(/acct:/, '').split('@').first
  user = User.first( :name => r_user )
  finger = Proudhon::Finger.new
  finger.subject = "acct:#{user.name}@#{ROOT}"
  finger.alias = "http://#{ROOT}/user/#{user.name}"
  finger.links[:updates_from] = "http://#{ROOT}/user/#{user.name}/feed"
  finger.links[:mention] = "http://#{ROOT}/salmon"
  finger.links[:replies] = "http://#{ROOT}/salmon"
  finger.links[:salmon] = "http://#{ROOT}/salmon"
  finger.links[:profile] = "http://#{ROOT}/user/#{user.name}"
  key = OpenSSL::PKey::RSA.new(user.private_key)
  finger.links[:magic_key] = Proudhon::MagicKey.to_s(key)
  finger.links[:hcard] = "http://#{ROOT}/user/#{user.name}"

  content_type 'application/xrd+xml'
  finger.to_xml
end

get '/.well-known/host-meta' do
  content_type 'application/xrd+xml'
  Proudhon::HostMeta.to_xml("http://#{ROOT}/webfinger/?id={uri}")
end

get '/pubsub/?' do
  topic = params['hub.topic']
  mode = params['hub.mode']

  params['hub.challenge']
end

get '/chat' do
  halt 404 unless settings.chat
  haml :chat
end

## Access Control
get '/login' do
  redirect '/' if session?

  haml :'user/login'
end

get '/signup' do
  redirect '/' if session?
  haml :'user/signup'
end

get '/reset' do
  redirect '/' if session?

  haml :'user/reset'
end

get '/settings' do
  session!

  haml :'user/settings'
end

get '/settings/delete' do
  session!

  haml :'user/settings_delete'
end

get '/logout' do
  session_end!

  redirect '/', :success => 'You\'ve been logged out.'
end