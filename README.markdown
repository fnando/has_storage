has_storage
===========

Organize directories and files, respecting a maximum number of items per 
directory.

Instalation
-----------

1) Install the plugin with `script/plugin install git://github.com/fnando/has_storage.git`
2) Generate a migration with `script/generate migration create_storages` and add the following code:

	class CreateStorages < ActiveRecord::Migration
	  def self.up
	    create_table :storages do |t|
	      t.string :name, :cluster
	    end
    
	    add_index :storages, [:name, :cluster]
	  end

	  def self.down
	    drop_table :storages
	  end
	end

3) Add the fields `attachment_path`, `attachment_content_type` and `attachment_size` to your model. 
   Just run `script/generate migration add_attachment_fields_to_user`.

	class AddAttachmentFieldsToUser < ActiveRecord::Migration
	  def self.up
		add_column :user, :attachment_size, :integer
		add_column :user, :attachment_path, :text
		add_column :user, :attachment_content_type, :string
	  end
	end

3) Run the migrations with `rake db:migrate`

Usage
-----

1) Add the method call `has_storage` to your model.

	class User < ActiveRecord::Base
	  has_storage
  
	  attr_accessible :avatar_file
  
	  after_save :save_avatar
  
	  private
	    def save_avatar
	      return if avatar_file.blank?
	      write_attribute(:avatar_path, allocate(:avatars, :file => avatar_file, :file_name => "#{id}-avatar.jpg"))
	      self.avatar_file = nil
	      save
	    end
	end

2) Available options:

	:base_dir  => Where the storage directory will reside. Can be interpolated.
	:from      => The file that will be saved/moved. Can be an string, File object or Upload object
	:to        => The output file name. Can be interpolated.
	:hex       => Save cluster sloth as hex number
	:depth     => Define the cluster structure depth
	:max_items => How many items per directory
	:processor => An array of processors (see below)
    
To remove any saved file, just add `after_destroy :destroy_file!`.
This will update the model if nil values.
    
Some options can be interpolated, like `:base_dir`, `:to` and `:from`. This means
that you can set attributes/methods from the instance object to build your path.
    
	has_storage :base_dir => ":rails_root/storage", :to => ":user_id-:uid.:extension"
    
The option above will set a final path like `{Rails.root}/storage/1/200/400/500-abcefghij.pdf`.
Here's the recognized interpolation placeholders:
    
	:rails_root => The value from RAILS_ROOT constant
	:storage_name => The class name using :tableize method
	:base_name  => The :from file name without the extension
	:name       => The :from file name with the extension
	:extension  => The extension from the file defined by :from
    
The best way of defining the path is to set the path that can be changed as the :base_dir and
to put the rest in the :to path. Just make sure the base_dir do not use any value from the instance.
    
	has_storage :base_dir => ":rails_root/storage",
	  :to => ":storage_name/:id-:base_name.:extension"
    
You can apply post processors. Just define a new class like
    
	class SimplesIdeias::Storages::Processor::Ocr
	  def initialize(options)  
	  end

	  def run
	  end
	end
    
The ActiveRecord instance will respond to a `file` attribute; is this attribute that
you have to set the file
    
	@user.file = params[:avatar]
	@user.file = "/tmp/avatar.jpg"
	@user.file = File.open("/tmp/avatar.jpg", "rb")
    
**NOTE:** The master branch has a new implemention; for the old one, use the tag `stable-1`.

Copyright (c) 2007-2008 Nando Vieira, released under the MIT license