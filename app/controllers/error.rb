not_found do
  haml :"static/error", :locals => { :message => "Couldn't find what you were looking for. Sorry." }
end

error do
  haml :"static/error", :locals => { :message => env['sinatra.error'].message }
end
