require 'stalker'
require 'app'
include Stalker

job 'notify' do |args|
  activity = Activity.first( :id => args['id'] )
  args['users'].to_a.each do |target|
    activity.notifications << Notification.create(:kind => args['kind'].to_sym, :user_id => target, :sender => activity.user, :activity => activity, :parent => activity.parent || activity)
  end
end

job 'email' do |args|

end

job 'pubsubhub' do |args|

end
