class Friendship
  include DataMapper::Resource

  property :id, Serial
  property :accepted, Boolean, :default => true, :required => true
  property :updated_at, DateTime
  property :created_at, DateTime

  belongs_to :user
  belongs_to :friend, :model => 'User'

  validates_uniqueness_of :friend_id, :scope => :user_id

  before :create do
    self.accepted = false if friend.blob[:private] == true
  end
end