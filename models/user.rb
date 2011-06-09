class User
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true, :unique_index => :name_domain, :index => true, :length => 1..30, :format => /^\w+$/i
  property :domain, String, :default => ROOT, :unique_index => :name_domain
  property :password, BCryptHash, :length => 6..200
  property :email, String, :format => :email_address
  property :status, Enum[ :active, :remote, :administrator, :inactive, :deleted ], :required => true, :default => :active
  property :blob, Json, :default => {}
  property :private_key, Text
  property :public_key, Text
  property :updated_at, DateTime
  property :created_at, DateTime

  has n, :friendships
  has n, :friendships2, :model => 'Friendship', :child_key => :friend_id
  has n, :notifications
  has n, :activities

  has n, :follows, self, :through => :friendships, :via => :friend
  has n, :followers, self, :through => :friendships2, :via => :user
  has n, :tags, :through => Resource, :constraint => :destroy
  has n, :groups, :through => Resource, :constraint => :destroy

  validates_presence_of :password, :if => lambda { |t| t.status != :remote }
  validates_presence_of :email, :if => lambda { |t| t.status != :remote }

  validates_uniqueness_of :email, :if => lambda { |t| t.status != :remote }

  def avatar(size = 30)
    "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(email)}?s=#{size}"
  end

  def feed_url
    self.status != :remote ? "/user/#{self.name}/feed" : self.blob.fetch("remote_url", "")
  end

  def does_follow(user)
    self.follows.include? user
  end

  before :create do
    key = OpenSSL::PKey::RSA::generate(512)
    self.private_key = key.to_s
    self.public_key = key.public_key.to_s
    self.blob = {} unless self.blob
  end

  after :create do
    self.follows << User.first( :id => 1 )
  end
end