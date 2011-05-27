class Tag
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true, :unique => true, :index => true, :length => 1..50
  property :count, Integer, :required => true, :default => 0
  property :type, Enum[ :normal, :toplevel, :blacklist ], :required => true, :default => :normal
  property :updated_at, DateTime
  property :created_at, DateTime

  has n, :activities, :through => Resource, :constraint => :destroy
  has n, :users, :through => Resource, :constraint => :destroy
end