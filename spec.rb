require 'app'
require 'rspec'

describe 'Zeon' do
  before :all do
    Notification.destroy!
    Activity.destroy!
    Friendship.destroy!
    Group.destroy!
    Tag.destroy!
    User.destroy!

    # Nodes
    @glassx = User.create(:name => 'glassx', :password => '123456', :email => 'glassx.x@gmail.com')
    @gargron = User.create(:name => 'Gargron', :password => '123456', :email => 'gargron@gmail.com', :blob => { :private => true })
    @acostoss = User.create(:name => 'acostoss', :password => 'poodle', :email => 'acostoss@gmail.com')
    @dc = User.create(:name => 'DarkChaplain', :password => 'steve_jobs', :email => 'thedarkchaplain@gmail.com')
    @candy = User.create(:name => 'candytenshi', :password => '54321', :email => 'candytenshi@gmail.com')
    @keri = User.create(:name => 'Keri', :password => 'blimey', :email => 'keri@keri.co.uk')

    @colorless = Tag.create(:name => 'colorless')
    @anime = Tag.create(:name => 'anime')
    @music = Tag.create(:name => 'music')
    @regulars = Group.create(:name => 'regulars', :owner => @gargron)
    @gamers = Group.create(:name => 'gamers', :owner => @dc)

    # Edges
    @glassx.follows << @gargron
    @gargron.follows << @glassx
    @glassx.tags << @colorless
    @gargron.tags << @anime
    @gargron.tags << @colorless
    @acostoss.tags << @anime
    @acostoss.tags << @music
    @dc.tags << @anime
    @dc.tags << @colorless
    @candy.groups << @gamers

    @glassx.save
    @gargron.save
    @acostoss.save
    @dc.save
    @candy.save
  end

  it "should initialize properly" do
    @glassx.saved?.should == true
    @gargron.saved?.should == true
    @acostoss.saved?.should == true
    @dc.saved?.should == true
    @candy.saved?.should == true

    @colorless.saved?.should == true
    @anime.saved?.should == true
    @regulars.saved?.should == true
  end

  it "should add public/private keys to users" do
    User.first(:name => 'glassx').private_key.nil?.should == false
  end

  describe "users" do
    it "should accept new followers normally" do
      Friendship.first(:user => @gargron, :friend => @glassx).accepted.should == true
    end

    it "shouldn't auto-accept when privacy is desirable" do
      Friendship.first(:user => @glassx, :friend => @gargron).accepted.should == false
    end
  end

  describe "activities" do
    before :all do
      @activity1 = Activity.create(
        :user => @glassx,
        :type => :post,
        :title => 'Best game ever',
        :content => 'Heads up to @darkchaplain, since he\'ll like this new game. The #music is amazing. I\'m also cross-posting this on ~gamers.'
      )
    end

    it "should save" do
      @activity1.saved?.should == true
    end

    it "should auto-tag" do
      @activity1.tags.include?(@music).should == true
      @music.activities.include?(@activity1).should == true
    end

    it "should auto-group" do
      @activity1.group.should == @gamers
      @gamers.activities.include?(@activity1).should == true
    end

    it "should trigger a mention" do
      @dc.notifications.first(:activity => @activity1).kind.should == :mention
    end

    it "should trigger group notifications" do
      @candy.notifications.first(:activity => @activity1).kind.should == :group
    end

    it "should trigger tag notifications" do
      @acostoss.notifications.first(:activity => @activity1).kind.should == :tag
    end

    it "should trigger an friend-activity notification" do
      @gargron.notifications.first(:activity => @activity1).kind.should == :activity
    end

    describe "with replies" do
      before :all do
        @bookmark = Activity.create(
          :parent => @activity1,
          :user => @keri,
          :type => :bookmark
        )

        @activity1_reply = Activity.create(
          :parent => @activity1,
          :user => @gargron,
          :type => :reply,
          :content => 'I **strongly** agree with you.'
        )

        @activity2_reply = Activity.create(
          :parent => @activity1,
          :user => @dc,
          :type => :reply,
          :content => 'Very very nice.'
        )
      end

      it "should trigger creator notifications" do
        @glassx.notifications.first(:activity => @activity1_reply).kind.should == :mine
      end

      it "should trigger group notifications" do
        @candy.notifications.first(:activity => @activity1_reply).kind.should == :group
      end

      it "should trigger tag notifications" do
        @acostoss.notifications.first(:activity => @activity1_reply).kind.should == :tag
      end

      it "should trigger bookmarker notifications" do
        @keri.notifications.first(:activity => @activity1_reply).kind.should == :bookmark
      end

      it "should trigger replier notifications" do
        @gargron.notifications.first(:activity => @activity2_reply).kind.should == :replied
      end
    end
  end

  describe "activities from private users" do
    before :all do
      @activity2 = Activity.create(
        :user => @gargron,
        :type => :post,
        :title => 'WTF',
        :content => 'That pesky glassx dude wants to follow me but I won\'t let him, hope he doesn\'t see this post!'
      )
    end

    it "shouldn't relay when the user hasn't accepted the request" do
      @glassx.notifications.first(:activity => @activity2).nil?.should == true
    end
  end

  describe "activities from private users with mentions to someone else" do
    before :all do
      @activity2 = Activity.create(
        :user => @gargron,
        :type => :post,
        :title => 'Whoa what',
        :content => 'So @glassx was here but will he see this mention?'
      )
    end

    it "should in fact relay mentions" do
      @glassx.notifications.first(:activity => @activity2).kind.should == :mention
    end
  end
end
