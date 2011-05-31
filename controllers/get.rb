get '/' do
  if session?
    redirect '/home'
  else
    redirect '/all'
  end
end

get %r{/all(/type:[post|image|link|video]+)?(/[creator|poster]+:[\w]+)?(/sort:[popular|latest|oldest|updated|neglected]+)?(/page/[\d]+)?} do |r_type, r_user, r_sort, r_page|
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

  @posts = Activity.all( default ).paginate( :page => page, :per_page => 15 )

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

  @activity = @cur_user.notifications( :kind => inbox.nil? ? [ :activity, :replied, :liked, :tag, :group] : [ :message, :mention ] ).activities( :order => :id.desc ).paginate( :page => p, :per_page => 10 )
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

## Profiles
get '/user/:user/?' do |user|
  @user = User.first( :name => user )

  haml :"profile"
end

get '/user/:user/feed/?' do |user|
  # Atom feed
  @user = User.first( :name => user )
  halt 404 unless @user
  atom = Proudhon::Atom.new
  atom.id = "http://#{ROOT}/user/#{user}/feed"
  atom.title = @user.name
  atom.generator = settings.site_title
  atom.author = Proudhon::Author.new
  atom.author.name = @user.name
  atom.author.uri = "http://#{ROOT}/user/#{user}"
  atom.author.links[:alternate] = "http://#{ROOT}/user/#{user}"
  atom.author.links[:avatar] = @user.avatar
  atom.links[:alternate] = "http://#{ROOT}/user/#{user}"
  atom.links[:self] = "http://#{ROOT}/user/#{user}/feed"
  atom.links[:hub] = "http://pubsubhubbub.appspot.com/"
  atom.links[:profile] = "http://#{ROOT}/user/#{user}"

  atom.entries = Activity.all( :type => [:post, :image, :video, :link], :parent_id => nil, :user => @user, :order => :id.desc ).map do |a|
    entry = Proudhon::Entry.new
    entry.id = "tag:#{ROOT};#{a.id.to_s}"
    entry.title = feed_title(a)
    entry.content = feed_content(a)
    entry.updated = Time.parse(a.updated_at.to_s)
    entry.published = Time.parse(a.created_at.to_s)
    entry.verb = a.type
    entry.objtype = a.type
    entry.links[:alternate] = entry.id
    entry
  end

  content_type 'application/atom+xml'
  atom.to_xml
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

get '/chat' do
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
  kill_session!

  redirect '/', :success => 'You\'ve been logged out.'
end