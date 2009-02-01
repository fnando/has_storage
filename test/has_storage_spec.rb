require File.dirname(__FILE__) + "/spec_helper"

# unset models used for testing purposes
Object.unset_class('User')

class User < ActiveRecord::Base
  has_storage
end

describe "has_storage" do
  fixtures :users
  
  before(:each) do
    @user = users(:homer)
    @image = File.expand_path(File.dirname(__FILE__) + '/fixtures/rails.png')
    @file = File.open(@image, "rb")
    
    User.has_storage_options = {
      :depth => 3,
      :hex => false,
      :base_dir => "#{Rails.root}/public/storage"
    }
  end
  
  after(:each) do
    system "rm -rf #{Rails.root}/public/storage" if File.directory?("#{Rails.root}/public/storage")
    system "rm -rf #{Rails.root}/tmp/storage" if File.directory?("#{Rails.root}/tmp/storage")
  end
  
  it "should raise if no storage name is given" do
    doing { @user.allocate }.should raise_error
  end
  
  it "should return storage path for without file" do
    @user.storage_path_for(:avatars).should == "#{Rails.root}/public/storage/avatars"
  end
  
  it "should return storage path for with file" do
    @user.storage_path_for(:avatars, 'file.jpg').should == "#{Rails.root}/public/storage/avatars/file.jpg"
  end
  
  it "should return storage path for with storage and file" do
    @user.storage_path_for(:avatars, '1/1', 'file.jpg').should == "#{Rails.root}/public/storage/avatars/1/1/file.jpg"
  end
  
  describe "defaults" do
    it "using :directory should create directory at ./public/storages/avatars" do
      @user.allocate(:avatars, :directory => @user.id)
      File.should be_directory("#{Rails.root}/public/storage/avatars/1/1/#{@user.id}")
    end
    
    it "using :file with a path should create file at ./public/storages/avatars" do
      @user.allocate(:avatars, :file => @image)
      File.should be_file("#{Rails.root}/public/storage/avatars/1/1/rails.png")
    end
    
    it "using :file with a path should use :file_name when creating file at ./public/storages/avatars" do
      @user.allocate(:avatars, :file => @image, :file_name => "some_file.png")
      File.should be_file("#{Rails.root}/public/storage/avatars/1/1/some_file.png")
    end
    
    it "using :file with a file pointer should create file at ./public/storages/avatars" do
      @storage = @user.allocate(:avatars, :file => @file, :file_name => "rails.png")
      File.should be_file("#{Rails.root}/public/storage/avatars/1/1/rails.png")
    end
    
    it "using :file with a file pointer and no :file_name should raise an error" do
      doing { @user.allocate(:avatars, :file => @file) }.should raise_error
    end
  end
  
  describe "custom base_dir" do
    before(:each) do
      User.has_storage_options[:base_dir] = "#{Rails.root}/tmp/storage"
    end
    
    it "using :directory should create directory at ./tmp/storages" do
      @user.allocate(:avatars, :directory => @user.id)
      File.should be_directory("#{Rails.root}/tmp/storage/avatars/1/1/#{@user.id}")
    end
    
    it "using :file with a path should create file at ./tmp/storages" do
      @storage = @user.allocate(:avatars, :file => @image)
      File.should be_file("#{Rails.root}/tmp/storage/avatars/#{@storage}/rails.png")
    end
    
    it "using :file with a file pointer should create file at ./tmp/storages" do
      @storage = @user.allocate(:avatars, :file => @file, :file_name => "rails.png")
      File.should be_file("#{Rails.root}/tmp/storage/avatars/#{@storage}/rails.png")
    end
  end
  
  describe "custom hex" do
    before(:each) do
      User.has_storage_options[:hex] = true
      Storage.create :name => "avatars", :cluster => "255/300/400"
    end
    
    it "should create storage path using hex" do
      @storage = @user.allocate(:avatars, :file => @image)
      @storage.should == "FF/12C"
    end
  end
  
  describe "custom depth" do
    before(:each) do
      User.has_storage_options[:depth] = 6
    end
    
    it "should create storage with custom depth" do
      @storage = @user.allocate(:avatars, :file => @image)
      File.should be_file("#{Rails.root}/public/storage/avatars/1/1/1/1/1/rails.png")
    end
  end
  
  describe "storage" do
    before(:each) do
      User.has_storage_options[:depth] = 3
      User.has_storage_options[:max_items] = 2
    end
    
    it "should increment storage path" do
      @user.allocate(:avatars, :file => @image).should == "1/1"
      @user.allocate(:avatars, :file => @image).should == "1/1"
      @user.allocate(:avatars, :file => @image).should == "1/2"
      @user.allocate(:avatars, :file => @image).should == "1/2"
      @user.allocate(:avatars, :file => @image).should == "2/1"
      @user.allocate(:avatars, :file => @image).should == "2/1"
      @user.allocate(:avatars, :file => @image).should == "2/2"
    end
  end
end