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
    if image = Activity.create( :type => :image, :user => @cur_user, :content => params[:text], :meta => params[:url].empty? ? {} : { :source_url => params[:url] }, :image => paper_hash(params[:image_file]) ) and image.saved?
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
      if oembed = OEmbed.valid?(params[:url], "maxwidth" => "600", "maxheight" => "350")
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
  session!

  a = Activity.first( :id => id.to_i )

  unless @cur_user.id == a.user_id or @cur_user.status == :administrator
    raise "You are not allowed to delete this post."
  end

  # Delete Activity
  if a.destroy
    redirect '/home'
  else
    redirect back
  end
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
      else
        redirect '/thread/' + id.to_s + '#reply', :error => reply.errors.to_a.join(' - ')
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

post '/salmon/?' do
  xml = CGI.unescape(request.env["rack.input"].read)
  salmon = Proudhon::Salmon.new(xml)
  entry = Proudhon::Entry.new(salmon.content)
  finger = Proudhon::Finger.fetch entry.author.uri

  subject = finger.subject.gsub(/acct:/, '').split('@')
  name = subject[0]
  domain = subject[1]

  user = User.first( :name => name, :domain => domain) || User.create( :status => :remote, :name => name, :domain => domain )

  case entry.verb
  when :post, :reply, :like
    type = entry.verb
    replyto = entry.replyto.to_s.gsub(/tag:[\w+].[\w+];/, '')
    post = Activity.create( :user => user, :type => type, :title => entry.title, :content => entry.content, :parent_id => replyto )
  when :follow
    #user.follows << entry
  end

end

post '/pubsub/?' do
  xml = CGI::unescape(request.body.read)

  logger = Logger.new('logfile.log')
  logger2 = Logger.new('postfile.log')
  logger.info("POST")
  logger2.info("POST") { xml }

  atom = Nokogiri::XML::Document.parse xml

  entries = atom.css("entry")

  logger.info("Entries") { entries.length }

  entries.each do |re|
    e = re.children
    entry = {
      :uri => e.at_css("author uri").content,
      :name => e.at_css("author name").content,
      :published => e.at_css("published").content,
      :updated => e.at_css("updated").content,
      :title => e.at_css("title").nil? ? nil : e.at_css("title").content,
      :content => e.at_css("content").nil? ? nil : e.at_css("content").content,
      :link => e.at_css("link[rel=enclosure]").nil? ? nil : e.at_css("link[rel=enclosure]")["href"],
      :image => e.at_css("fullImage").nil? ? nil : e.at_css("fullImage").content,
      :objtype => e.at_xpath("//activity:object/activity:object-type").content
    }

    # Find remote user
    uri = URI.parse entry[:uri]
    user = User.first( :name => entry[:name], :domain => uri.host )

    logger.info("User") { user.name + "@" + user.domain }

    # Otherwise skip, no anons wanted
    next unless user

    meta = {}
    image = nil

    # Type-specific things
    case entry[:objtype]
    when "http://activitystrea.ms/schema/1.0/article"
      type = :post
    when "http://activitystrea.ms/schema/1.0/image"
      type = :image
      entry[:title] = nil
      image = download_image(entry[:image])
      meta["source_url"] = entry[:link]
    when "http://activitystrea.ms/schema/1.0/video"
      type = :video
      meta["video_url"] = entry[:link]
      if oembed = OEmbed.valid?(entry[:link], "maxwidth" => "600", "maxheight" => "350")
        meta["video_html"] = oembed.to_s
      end
    when "http://activitystrea.ms/schema/1.0/review"
      type = :link
      meta["url"] = entry[:link]
    end

    logger.info("Type") { entry[:objtype] + ": " + type.to_s }

    # If post type is unknown, balls to it
    next unless type

    # Well then, create the post
    if post = Activity.create(
      :user => user,
      :type => type,
      :title => entry[:title],
      :content => entry[:content],
      :image => image,
      :meta => meta,
      :created_at => Time.parse(entry[:published]),
      :updated_at => Time.parse(entry[:updated])
    ) and post.saved?
      logger.info("Created post") { post.type.to_s +  + " / " + post.title.to_s }
      next
    else
      logger.error("Creating post") { post.errors.to_a.join(" / ") }
    end
  end

end

post '/follow' do
  session!

  redirect '/follow', :error => "Empty ID!" unless not params[:user_id].nil?

  finger = Proudhon::Finger.fetch params[:user_id]

  unless !finger.nil?
    raise "Couldn't finger the user's feed"
  end

  feed = finger.links[:updates_from]
  gravatar = URI.parse finger.links[:gravatar].to_s
  gravatar_hash = gravatar.path.gsub(/\/avatar\//, '')
  subject = finger.subject.gsub(/acct:/, '').split('@')
  name = subject[0]
  domain = subject[1]

  user = User.first( :name => name, :domain => domain) || User.create( :status => :remote, :name => name, :domain => domain, :blob => { 'remote_url' => feed, 'email_hash' => gravatar_hash } )

  if user.id == @cur_user.id
    redirect '/follow', :error => "Cannot follow self. It's like dividing by zero in an unobserved room."
  end

  if @cur_user.does_follow user
    user.blob = user.blob.merge( "remote_url" => feed, "email_hash" => gravatar_hash )
    if user.save
      flash.now[:notice] = "Feed URL and other user data updated, anyway"
    end
    redirect '/follow', :error => "Already following #{name}"
  end

  @cur_user.follows << user
  @cur_user.save

  unless @cur_user.saved?
    redirect '/follow', :error => "Dammit, there was a problem following #{name}"
  end

  unless user.domain == ROOT
    atom = Proudhon::Atom.from_uri feed
    if atom.subscribe "http://#{ROOT}/pubsub"
      go_on = true
    end
  else
    go_on = true
  end
  if go_on
    redirect '/follow', :notice => "Yay! Now you're following #{name}"
  end
end

post '/user/:id/:action' do |id, action|
  session!

  if action == "follow"
    user = User.first( :id => id )
    @cur_user.follows << user
    @cur_user.save
    if @cur_user.saved?
      redirect '/home', :notice => "You are now following #{user.name}"
    end
  end
end

post '/login' do
  redirect '/' if session?

  if user = User.first(:name => params[:name], :status => [:active, :administrator]) and user.password == params[:password]
    session_start!
    session[:id], session[:name], session[:email] = user.id, user.name, user.email
    redirect '/', :notice => 'Login successful!'
  else
    redirect '/login', :error => "Wrong username/login combination"
  end
end

post '/signup' do
  redirect '/' if session?

  if user = User.create(:name => params[:name], :password => params[:password], :email => params[:email]) and user.saved?
    session_start!
    session[:id], session[:name], session[:email] = user.id, user.name, user.email
    redirect '/', :notice => "Account #{user.name} successfully created!"
  else
    flash.now[:error] = user.errors.to_a.join(' - ')
  end

  haml :'user/signup'
end

post '/reset' do
  redirect '/' if session?

  if params[:email].length < 1
    redirect '/reset', :error => "E-mail must not be blank"
  end

  if user = User.first(:email => params[:email])
    #logger = Logger.new('logfile.log')
    new_pass = (rand(2**32) + 2**32).to_s(36)
    #logger.info("Password") { new_pass }
    user.password = new_pass
    user.save
  end

  redirect '/reset', :notice => "If you're registered with us, your new password was just sent to your e-mail."
end

post '/settings' do
  session!

  if @cur_user.password == params[:password]
    @cur_user.password = params[:new_password]
    @cur_user.email = params[:email]
    @cur_user.save

    redirect '/settings', :notice => "Successfully saved!"
  else
    redirect '/settings', :error => "Wrong password!"
  end
end

post '/profile/delete' do
  session!

  if @cur_user.password == params[:password]
    @cur_user.status = :deleted
    @cur_user.save
    session_end!
    redirect '/', :notice => "Your account was terminated."
  else
    flash.now[:error] = "Wrong password!"
  end

  haml :'user/profile_delete'
end