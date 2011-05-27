class Group
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true, :unique => true, :index => true, :length => 1..50
  property :description, Text
  property :count, Integer, :required => true, :default => 0
  property :updated_at, DateTime
  property :created_at, DateTime

  belongs_to :owner, :model => 'User'

  has n, :activities
  has n, :users, :through => Resource, :constraint => :destroy
end