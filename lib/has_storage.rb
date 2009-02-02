module SimplesIdeias
  module Storages
    def self.included(base)
      base.extend SimplesIdeias::Storages::ClassMethods
      
      class << base
        attr_accessor :has_storage_options
        attr_accessor :has_storage_default_options
      end
    end
    
    module Processor
    end
    
    module ClassMethods
      # USAGE: has_storage options={}
      # Available options:
      #
      #   :base_dir  => Where the storage directory will reside. Can be interpolated.
      #   :from      => The file that will be saved/moved. Can be an string, File object or Upload object
      #   :to        => The output file name. Can be interpolated.
      #   :hex       => Save cluster sloth as hex number
      #   :depth     => Define the cluster structure depth
      #   :max_items => How many items per directory
      #   :processor => An array of processors (see below)
      #
      # To remove any saved file, just add `after_destroy :destroy_file!`.
      # This will update the model if nil values.
      #
      # Some options can be interpolated, like :base_dir, :to and :from. This means
      # that you can set attributes/methods from the instance object to build your path.
      #
      #   has_storage :base_dir => ":rails_root/storage", :to => ":user_id-:uid.:extension"
      #
      # The option above will set a final path like `#{Rails.root}/storage/1/200/400/500-abcefghij.pdf`.
      # Here's the recognized interpolation placeholders:
      #
      #   :rails_root => The value from RAILS_ROOT constant
      #   :storage_name => The class name using :tableize method
      #   :base_name  => The :from file name without the extension
      #   :name       => The :from file name with the extension
      #   :extension  => The extension from the file defined by :from
      #
      # The best way of defining the path is to set the path that can be changed as the :base_dir and
      # to put the rest in the :to path. Just make sure the base_dir do not use any value from the instance.
      #
      #   has_storage :base_dir => ":rails_root/storage",
      #     :to => ":storage_name/:id-:base_name.:extension"
      #
      # You can apply post processors. Just define a new class like
      # 
      #   class SimplesIdeias::Storages::Processor::Ocr
      #     def initialize(options)  
      #     end
      #
      #     def run
      #     end
      #   end
      #
      # The ActiveRecord instance will respond to a `file` attribute; is this attribute that
      # you have to set the file
      #
      #   @user.file = params[:avatar]
      #   @user.file = "/tmp/avatar.jpg"
      #   @user.file = File.open("/tmp/avatar.jpg", "rb")
      #
      def has_storage(options={})
        include SimplesIdeias::Storages::InstanceMethods
        
        self.has_storage_default_options = {
          :max_items => 4096,
          :base_dir => "#{RAILS_ROOT}/public/storage",
          :to => ":storage_name/:id-:base_name.:extension",
          :hex => false,
          :depth => 3
        }
        
        self.has_storage_options = has_storage_default_options.merge(options)
      end
    end
    
    module InstanceMethods
      attr_accessor :file
      
      def attachment
        @attachment ||= SimplesIdeias::Storages::Attachment.new(self)
      end
      
      def attachment_full_path
        attachment.full_path
      end
      
      def attachment?
        attachment.exists?
      end
      
      def save_attachment
        attachment.save
      end
      
      def destroy_attachment
        attachment.destroy
      end
      
      def storage_settings
        self.class.has_storage_options
      end
    end
  end
end