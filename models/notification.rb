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
    if self.kind == :mention
      Stalker.enqueue('email', :a_id => :activity_id, :u_id => :user_id, :type => 'mention')
    end
  end
end