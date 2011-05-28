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
    if image = Activity.create( :type => :image, :user => @cur_user, :content => params[:text], :meta => params[:url].empty? ? {} : { :source_url => params[:url] }, :image => paper_hash(params[:image_file]), :image_dimensions => dimensions.width.round.to_s + "x" + dimensions.height.round.to_s ) and image.saved?
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