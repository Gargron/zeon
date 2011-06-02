class Activity
  include DataMapper::Resource
  include DataMapper::Validate
  include Paperclip::Resource

  property :id, Serial
  property :type, Enum[ :post, :reply, :comment, :link, :image,
    :video, :question, :event, :like, :bookmark, :vote, :tag,
    :attendance, :invitation, :poke, :recommendation, :message,
    :announcement, :follow, :unfollow ], :required => true, :index => true
  property :title, String
  property :content, Text
  property :meta, Json, :default => {}
  property :updated_at, DateTime
  property :created_at, DateTime

  belongs_to :user
  belongs_to :parent, :model => 'Activity', :required => false
  belongs_to :group, :required => false

  has n, :children, :model => 'Activity', :child_key => [ :parent_id ]
  has n, :notifications
  has n, :tags, :through => Resource, :constraint => :destroy

  has_attached_file :image,
                    :path => Dir.pwd + '/public/uploads/:attachment/:id/:style/:filename',
                    :url => '/uploads/:attachment/:id/:style/:filename',
                    :styles => { :thumb_all => '200x150>', :thumb_dash => '220x240>', :medium => '600x1000>' }

  property :image_dimensions, String

  validates_presence_of :title, :if => lambda { |t| REQUIRES_TITLE.include? t.type }
  validates_presence_of :content, :if => lambda { |t| [:post, :reply].include? t.type }

  validates_attachment_presence :image, :if => lambda { |t| t.type == :image }
  validates_attachment_content_type :image, :content_type => [ "image/png", "image/jpg", "image/jpeg", "image/gif" ]
  validates_attachment_size :image, :in => 1..5242880

  validates_uniqueness_of :user_id, :scope => [:parent_id, :type], :if => lambda { |t| t.type == :like }

  ## Constants
  REQUIRES_TITLE = [ :post, :link, :video, :question, :event ]
  NEW_CONTENT = [ :post, :image, :link, :video, :question, :event ]
  CONTENT = [ :post, :reply, :comment, :link, :image, :video, :question, :event ]
  REPLY = [ :reply, :comment ]
  SPECIFIC = [ :follow, :unfollow, :like, :vote, :tag, :attendance ]
  PRIVATE = [ :bookmark, :vote, :invitation, :poke, :recommendation, :message ]
  MENTION = /(^|[\n ])@([\w]{1,30})/im
  HASHTAG = /#([a-z1-9]+)/i
  GROUPTAG = /~([a-z1-9]+)/i

  ## Callbacks
  after :create do
    # Denormalize
    if NEW_CONTENT.include? self.type
      self.meta = meta.merge( "post_count" => 1, "like_count" => 0, "bumped_id" => self.id, "bumped_by" => self.user.name, "bumped_at" => self.created_at )
      self.save
    end
    # Update parent's denormalization
    if REPLY.include? self.type
      self.parent.meta = parent.meta.merge( "post_count" => parent.meta.fetch("post_count", 1) + 1, "bumped_id" => self.id, "bumped_by" => self.user.name, "bumped_at" => DateTime.now )
      self.parent.updated_at = DateTime.now
      self.parent.save
    end
    if self.type == :like
      self.parent.meta = parent.meta.merge( "like_count" => parent.meta.fetch("like_count", 0) + 1 )
      self.parent.save
    end
    unless PRIVATE.include? self.type
      root = self.parent || self

      unless self.content.nil?
        mentions = User.all(:name => content.scan(MENTION))
        #self.tags = content.scan(HASHTAG).flatten.map {|t| Tag.first(:name => t) || Tag.create(:name => t) }
        self.group = Group.first(:name => content.scan(GROUPTAG))
        self.save

        #notify(:mention, mentions)
        Stalker.enqueue('notify', :id => self.id, :kind => :mention, :users => mentions.map { |u| u.id unless u.id == self.user.id } )
        #notify(:group, root.group.users) if root.group
        Stalker.enqueue('notify', :id => self.id, :kind => :group, :users => root.group.users.map { |u| u.id } ) if root.group
        #notify(:tag, root.tags.users)
        #Stalker.enqueue('notify', :id => self.id, :kind => :tag, :users => root.tags.users)
      end

      #notify(:activity, self.user.friendships2.all(:accepted => true).users)
      Stalker.enqueue('notify', :id => self.id, :kind => :activity, :users => self.user.friendships2.all(:accepted => true).users.map { |u| u.id } )
      #notify(:mine, [ root.user ])
      Stalker.enqueue('notify', :id => self.id, :kind => :mine, :users => [root.user.id])
      #notify(:bookmark, root.children(:type => :bookmark).users)
      Stalker.enqueue('notify', :id => self.id, :kind => :bookmark, :users => root.children(:type => :bookmark).users.map { |u| u.id } )
      #notify(:replied, root.children(:type => :reply).users)
      Stalker.enqueue('notify', :id => self.id, :kind => :replied, :users => root.children(:type => :reply).users.map { |u| u.id } )
      #notify(:liked, root.children(:type => :like).users)
      Stalker.enqueue('notify', :id => self.id, :kind => :liked, :users => root.children(:type => :like).users.map { |u| u.id } )
    end
  end

  def likes(cur_user)
    if likes = self.children( :type => :like, :user_id => cur_user) and likes.length > 0
      true
    else
      false
    end
  end

  def verb()
    case self.type
    when :post, :image
      "posted"
    when :reply
      "replied to"
    when :link, :video
      "shared"
    when :like
      "liked"
    end
  end

  def substantive(cur_user_id = 0)
    unless self.parent_id.nil?
      case self.parent.type
      when :post
        "#{cur_user_id == parent.user.id ? "your" : parent.user.name + "'s" } thread"
      when :link
        "#{cur_user_id == parent.user.id ? "your" : parent.user.name + "'s" } link"
      when :image
        "#{cur_user_id == parent.user.id ? "your" : parent.user.name + "'s" } image"
      when :video
        "#{cur_user_id == parent.user.id ? "your" : parent.user.name + "'s" } video"
      end
    else
      case self.type
      when :post
        "a thread"
      when :link
        "a link"
      when :image
        "an image"
      when :video
        "a video"
      end
    end

  end

  def add_tags(spaced_tags)
    unless spaced_tags.empty?
      spaced_tags = spaced_tags.scan(/[\w\s\!\(\)\&]/).join
      tags = spaced_tags.downcase.split(" ")
      self.tags = tags.flatten.map { |t| Tag.first(:name => t) || Tag.create(:name => t) }
      self.save
      Stalker.enqueue('notify', :id => self.id, :kind => :tag, :users => self.tags.users.map { |u| u.id })
    end
  end

  def notify(kind, users)
    users.each do |target|
      self.notifications << Notification.create(:kind => kind, :user => target, :sender => self.user, :activity => self, :parent => self.parent || self)
    end
  end
end