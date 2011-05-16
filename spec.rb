require 'app'
require 'rspec'

describe 'Zeon' do
  before :all do
    Friendship.destroy!
    Group.destroy!
    Tag.destroy!
    User.destroy!

    # Nodes
    @glassx = User.create(:name => 'glassx', :password => '123456', :email => 'glassx.x@gmail.com')
    @gargron = User.create(:name => 'gargron', :password => '123456', :email => 'gargron@gmail.com', :blob => { :private => true })
    @colorless = Tag.create(:name => 'colorless')
    @anime = Tag.create(:name => 'anime')
    @regulars = Group.create(:name => 'regulars', :owner => @gargron)

    # Edges
    @follow1 = Friendship.create(:user => @glassx, :friend => @gargron)
    @follow2 = Friendship.create(:user => @gargron, :friend => @glassx)
    @glassx.tags << @colorless
    @gargron.tags << @anime
    @regulars.users << @gargron
  end

  it "Should create nodes and edges" do
    @glassx.saved?.should == true
    @gargron.saved?.should == true
    @colorless.saved?.should == true
    @anime.saved?.should == true
    @regulars.saved?.should == true

    @follow1.saved?.should == true
    @follow2.saved?.should == true
  end

  it "Glass should have public/private keys" do
    User.first(:name => 'glassx').private_key.nil?.should == false
  end

  it "Glass should accept Gargron" do
    Friendship.first(:user => @gargron, :friend => @glassx).accepted.should == true
  end

  it "But Gargron shouldn't accept Glass" do
    Friendship.first(:user => @glassx, :friend => @gargron).accepted.should == false
  end

  
end
