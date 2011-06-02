require 'stalker'
require 'app'
include Stalker

def encode_activity(a, t)
  e = {
    :id => a.id,
    :title => a.title,
    :content => a.content,
    :type => a.type,
    :meta => a.meta,
    :verb => a.verb,
    :substantive => a.substantive(t),
    :image_dimensions => a.image_dimensions,
    :image => {
      :size => a.image.size,
      :url => a.image.url(:thumb_dash)
    },
    :created_at => a.created_at,
    :updated_at => a.updated_at,
    :user_id => a.user_id,
    :user => {
      :id => a.user.id,
      :name => a.user.name,
      :email => a.user.email,
      :avatar => a.user.avatar(48)
    },
    :parent_id => a.parent_id,
    :tags => a.tags,
    :likes => a.likes(t)
  }
  if !a.parent.nil?
    e[:parent] = {
      :id => a.parent.id,
      :title => a.parent.title,
      :content => a.parent.content,
      :type => a.parent.type,
      :meta => a.parent.meta,
      :image_dimensions => a.parent.image_dimensions,
      :image => {
        :size => a.parent.image.size,
        :url => a.parent.image.url(:thumb_dash)
      },
      :user => {
        :id => a.parent.user.id,
        :name => a.parent.user.name,
        :email => a.parent.user.email,
        :avatar => a.user.avatar(48)
      },
      :tags => a.parent.tags,
      :likes => a.parent.likes(t)
    }
  end
  e.to_json
end

job 'notify' do |args|
  activity = Activity.first( :id => args['id'] )
  args['users'].to_a.each do |target|
    # Database
    activity.notifications << Notification.create(:kind => args['kind'].to_sym, :user_id => target, :sender => activity.user, :activity => activity, :parent => activity.parent || activity)
    # Redis
    #if [].include? args['kind'].to_sym
    #  REDIS.zadd "notifications:inbox:#{target}", Time.parse(activity.created_at.to_s).to_i, encode_activity(activity, target)
    #  REDIS.zremrangebyrank "notifications:inbox:#{target}", 0, -200
    #else
    #  REDIS.zadd "notifications:home:#{target}", Time.parse(activity.created_at.to_s).to_i, encode_activity(activity, target)
    #  REDIS.zremrangebyrank "notifications:home:#{target}", 0, -200
    #end
  end

end

job 'email' do |args|

end

job 'pubsubhub' do |args|

end