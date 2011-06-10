require 'stalker'
require 'app'
include Stalker

job 'notify' do |args|
  activity = Activity.first( :id => args['id'] )
  args['users'].to_a.each do |target|
    # Database
    activity.notifications << Notification.create(:kind => args['kind'].to_sym, :user_id => target, :sender => activity.user, :activity => activity, :parent => activity.parent || activity)
  end

end

job 'email' do |args|

end

job 'pubsubpub' do |args|
  atom = Proudhon::Atom.new
  atom.links[:hub] = 'http://zeon.superfeedr.com'
  atom.links[:self] = "http://#{ROOT}/user/#{args['user']}/feed"
  begin
    atom.publish
    puts "Published"
  rescue => e
    puts "Didn't publish: " + e.response
  end
end