require 'app'
require 'rspec'

describe 'Zeon' do
  before(:all) do
    @dummy = User.create(:name => 'Dummy', :password => '123456', :email => 'very@dummy.com')
    @post = Activity.create(:type => :post, :user => @dummy, :title => 'I am so Dummy', :content => 'So Dummy, so Dummy as could be. Yeah!')
    @reply = Activity.create(:type => :reply, :user => @dummy, :parent => @post, :content => 'Fuck yeah poetry. Cool story bro. Really.')
  end
  
  it "should create a user" do
    @dummy.saved?.should == true
  end

  it "should post a freetext post" do
    @post.saved?.should == true
  end

  it "should reply to a post" do
    @reply.saved?.should == true
  end
end
