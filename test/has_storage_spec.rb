require File.dirname(__FILE__) + "/spec_helper"

# unset models used for testing purposes
Object.unset_class('User')

class User < ActiveRecord::Base
  has_storage
  
  after_save    :save_attachment
  after_destroy :destroy_attachment
end

class SimplesIdeias::Storages::Processor::Thumbnail
  def initialize(attachment)
    
  end
  
  def run
  end
end

class SimplesIdeias::Storages::Processor::Zip
  def initialize(attachment)
    
  end
  
  def run
  end
end

describe "has_storage" do
  fixtures :users
  
  before(:all) do
    @defaults = User.has_storage_default_options.dup
  end
  
  before(:each) do
    @homer = users(:homer)
    @barney = users(:barney)
    @options = @defaults.dup
    
    User.has_storage_options = @options
    
    @file = file_upload
  end
  
  after(:each) do
    system "rm -rf #{Rails.root}/public/storage 2>/dev/null"
    system "rm -rf #{Rails.root}/tmp/storage 2>/dev/null"
  end
  
  describe "default options" do
    it "should save using defaults" do
      @homer.file = @file
      @homer.save
      
      File.should be_file("#{Rails.root}/public/storage/users/1/1/#{@homer.id}-rails.png")
    end
    
    it "should create a new storage with default depth and max items" do
      Storage.create :name => "User", :cluster => "1/1/4096"
      
      @homer.file = @file
      @homer.save
      
      @barney.file = @file
      @barney.save
      
      File.should be_file("#{Rails.root}/public/storage/users/1/1/#{@homer.id}-rails.png")
      File.should be_file("#{Rails.root}/public/storage/users/1/2/#{@barney.id}-rails.png")
    end
  end
  
  describe "custom base_dir" do
    before(:each) do
      User.has_storage_options[:base_dir] = "#{Rails.root}/tmp/storage"
    end

    it "using :directory should create directory at ./tmp/storages" do
      @homer.file = @file
      @homer.save
      
      File.should be_file("#{Rails.root}/tmp/storage/users/1/1/#{@homer.id}-rails.png")
    end
  end
  
  describe "custom hex" do
    before(:each) do
      User.has_storage_options = @defaults.merge(:hex => true)
      Storage.create :name => "User", :cluster => "255/300/400"
    end

    it "should create storage path using hex" do
      @homer.file = @file
      @homer.save
      
      File.should be_file("#{Rails.root}/public/storage/users/FF/12C/#{@homer.id}-rails.png")
    end
  end
  
  describe "custom depth" do
    it "should create storage with custom depth" do
      User.has_storage_options[:depth] = 6
      
      @homer.file = @file
      @homer.save
      
      File.should be_file("#{Rails.root}/public/storage/users/1/1/1/1/1/#{@homer.id}-rails.png")
    end
  end
  
  describe "interpolation" do
    it "should use rails root" do
      User.has_storage_options[:base_dir] = ":rails_root/tmp/storage"
      
      @homer.file = @file
      @homer.save
      
      File.should be_file("#{Rails.root}/tmp/storage/users/1/1/#{@homer.id}-rails.png")
    end
    
    it "should use base name" do
      User.has_storage_options = @defaults.merge(:to => ":base_name")
      
      @homer.file = @file
      @homer.save
      
      File.should be_file("#{Rails.root}/public/storage/1/1/rails")
    end
    
    it "should use name" do
      User.has_storage_options[:to] = ":name"
      
      @homer.file = @file
      @homer.save
      
      File.should be_file("#{Rails.root}/public/storage/1/1/rails.png")
    end
    
    it "should use extension" do
      User.has_storage_options[:to] = "original.:extension"
      
      @homer.file = @file
      @homer.save
      @homer.reload
      
      File.should be_file("#{Rails.root}/public/storage/1/1/original.png")
    end
    
    it "should use storage name" do
      User.has_storage_options[:to] = ":storage_name/:base_name"
      
      @homer.file = @file
      @homer.save
      @homer.reload
      
      File.should be_file("#{Rails.root}/public/storage/users/1/1/rails")
    end
    
    it "should use hash" do
      User.has_storage_options[:to] = ":hash.:extension"
      
      @now = Time.now.utc
      Time.stub!(:now).and_return(@now)
      Digest::SHA1.should_receive(:hexdigest).with("#{@now}users#{@homer.id}").and_return("abc")
      
      @homer.file = @file
      @homer.save
      @homer.reload
      
      File.should be_file("#{Rails.root}/public/storage/1/1/abc.png")
    end
    
    it "should use custom placeholder" do
      User.has_storage_options[:to] = ":uid.:extension"
      @homer.should_receive(:uid).and_return("xyz")
      
      @homer.file = @file
      @homer.save
      @homer.reload
      
      File.should be_file("#{Rails.root}/public/storage/1/1/xyz.png")
    end
  end
  
  it "should update object with attachment info" do
    @homer.file = @file
    @homer.save
    
    @homer.reload
    
    @homer.attachment_size = @file.size
    @homer.attachment_content_type = "image/png"
    @homer.attachment_path = "1/1/#{@homer.id}-rails.png"
  end
  
  it "should return full path" do
    @homer.file = @file
    @homer.save
    
    @homer.reload
    
    path = "#{Rails.root}/public/storage/users/1/1/#{@homer.id}-rails.png"
    
    @homer.attachment_full_path.should == path
    @homer.attachment.full_path == path
    File.should be_file(@homer.attachment_full_path)
  end
  
  it "should remove file" do
    @homer.file = @file
    @homer.save
    @homer.reload
    
    output = "#{Rails.root}/public/storage/users/1/1/#{@homer.id}-rails.png"
    
    File.should be_file(output)
    @homer.destroy_attachment.should be_true
    File.should_not be_file(output)
  end
  
  it "should raise when file doesn't respond to :read method" do
    doing {
      @homer.file = "invalid"
      @homer.save
    }.should raise_error(SimplesIdeias::Storages::InvalidFileException)
  end
  
  it "should execute processor" do
    User.has_storage_options[:processor] = :thumbnail
    mock = mock("Thumbnail")
    SimplesIdeias::Storages::Processor::Thumbnail.should_receive(:new).with(anything).and_return(mock)
    mock.should_receive(:run)
    
    @homer.file = @file
    @homer.save
  end
  
  it "should execute multiple processors" do
    User.has_storage_options[:processor] = %w(thumbnail zip)
    mock = mock("processor", :null_object => true)
    
    SimplesIdeias::Storages::Processor::Thumbnail.should_receive(:new).with(anything).and_return(mock)
    SimplesIdeias::Storages::Processor::Zip.should_receive(:new).with(anything).and_return(mock)
    
    @homer.file = @file
    @homer.save
  end
  
  it "should ignore unknown processor" do
    doing {
      User.has_storage_options[:processor] = :ocr
      
      @homer.file = @file
      @homer.save
    }.should_not raise_error
  end
  
  private
    def file_upload
      path = File.expand_path(File.dirname(__FILE__) + '/fixtures/rails.png')
      
      mock(ActionController::UploadedStringIO, {
        :read => File.open(path, "rb").read,
        :content_type => "image/png",
        :original_filename => "rails.png",
        :size => File.size(path)
      })
    end
end