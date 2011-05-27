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

get '/signup' do
  redirect '/' if session?
  haml :'user/signup'
end

get '/reset' do
  redirect '/' if session?

  haml :'user/reset'
end

get '/profile' do
  session!

  haml :'user/profile'
end

get '/profile/delete' do
  session!

  haml :'user/profile_delete'
end

get '/logout' do
  session_end!

  redirect '/', :success => 'You\'ve been logged out.'
end