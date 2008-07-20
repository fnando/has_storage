module SimplesIdeias
  module Acts
    module Storages
      def self.included(base)
        base.extend SimplesIdeias::Acts::Storages::ClassMethods
        
        class << base
          attr_accessor :has_storage_options
        end
      end
      
      module ClassMethods
        # has_storage :base_dir => "#{Rails.root}/public/storage"
        # has_storage :hex => false
        # has_storage :depth => 3
        # has_storage :max_items => 4096
        def has_storage(options={})
          include SimplesIdeias::Acts::Storages::InstanceMethods
          
          self.has_storage_options = {
            :max_items => 4096,
            :base_dir => "#{RAILS_ROOT}/public/storage/#{name}",
            :hex => false,
            :depth => 3
          }.merge(options)
        end
      end
      
      module InstanceMethods
        # @user.storage_path_for(:avatars)
        # @user.storage_path_for(:avatars, "1.jpg")
        def storage_path_for(name, *args)
          parts = [self.class.has_storage_options[:base_dir], name.to_s, args]
          File.expand_path File.send(:join, *parts.flatten)
        end
        
        # This is how it works: the last part of the cluster 
        # is the file counter; when setting depth to 3, the 
        # saved cluster 1/2/3 denotes that the directory 1 has
        # 2 directories; the first directory has the maximum 
        # allowed items and the second has 3 files
        # allocate :avatars, :directory => "some_dir"
        # allocate :avatars, :file => "<File pointer>", :file_name => "file.jpg"
        # allocate :avatars, :file => "some/file/path"
        def allocate(name, options={})
          raise "You should specify the storage name" if name.to_s.blank?

          # find storage
          storage = Storage.find_by_name(name.to_s)

          unless storage
            # create storage if doesn't exists
            storage = Storage.create(:name => name.to_s, :cluster => Array.new(self.class.has_storage_options[:depth], 1).join("/"))
          end

          # last part of cluster info is the file counter
          cluster_parts = storage.cluster.split("/")
          cluster_parts.pop

          # storage will allocate a slot for a directory
          cluster_parts << options[:directory] if !!options[:directory]

          # convert directory names to correspondent hex
          # example: 1/1/160 will be saved as 1/1/a0
          cluster_parts.collect!{|dir| "%x" % dir.to_i } if self.class.has_storage_options[:hex]
          
          # join all cluster parts
          cluster_dirs = cluster_parts.join("/")

          # full cluster for later iteration and return
          cluster = storage.cluster

          # setting base directory
          base_dir = File.join(self.class.has_storage_options[:base_dir], name.to_s, cluster_dirs)

          # create directories structures if doesn't exists yet!
          File.makedirs(base_dir) unless File.directory?(base_dir)

          if options[:file] && options[:file].respond_to?(:read)
            # received a file stream but no name was given
            raise ":file_name is required" if options[:file_name].blank?

            # received a file stream, so write it to cluster
            File.open(File.join(base_dir, options[:file_name]), 'wb') do |f|
              f.write(options[:file].read)
            end
          elsif options[:file] && File.exists?(options[:file])
            # received a file path, so copy it to cluster
            file_name = options[:file_name] || File.basename(options[:file])
            File.copy options[:file], File.join(base_dir, file_name)
          end

          add_cluster = true

          # iterate reversed cluster array
          storage.cluster = storage.cluster.split("/").reverse.collect do |c|
            c = c.to_i

            # create a new cluster
            if add_cluster
              # if cluster is full, create a new one
              if c == self.class.has_storage_options[:max_items]
                c = 1
                add_cluster = true
              else
                # just increment this cluster
                c += 1
                add_cluster = false
              end
            end

            c
          end.reverse.join("/")
          
          storage.save
          cluster_dirs
        end
      end
    end
  end
end