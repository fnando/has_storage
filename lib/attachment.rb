module SimplesIdeias
  module Storages
    class InvalidFileException < StandardError; end
    
    class Attachment
      attr_writer :instance
      
      # The attachment class receive the AR instance
      def initialize(instance)
        @instance = instance
      end
      
      # Wrapper to the AR instance
      def instance
        @instance
      end
      
      # Return the storage AR object
      def storage
        @storage ||= Storage.find_by_name(instance_class)
      end
      
      # Return the full path to the file
      def full_path
        File.join(base_dir, instance.attachment_path)
      end
      
      # Return the interpolated base_dir
      def base_dir
        interpolate(instance.storage_settings[:base_dir])
      end
      
      # Check if the file exists in disk
      def exists?
        File.exists?(full_path)
      end
      
      # Remove the file from disk
      def destroy
        !!File.unlink(full_path) rescue false
      end
      
      # Save the file to the disk
      def save
        # return false if no file is provided
        return false if file.blank?
        raise SimplesIdeias::Storages::InvalidFileException, "file do not respond to the :read method" unless file.respond_to?(:read)
        
        # get the base_dir (includes only the interpolated :base_dir + partition)
        base_dir, slot = retrieve_storage_slot
        
        # get the complement (the interpolated :to)
        to = interpolate(instance.storage_settings[:to])
        
        # the output path is both base_dir + complement without filename + slot
        filename         = File.basename(to)
        output_dir       = File.join(*[File.dirname(to), slot].reject {|i| i == "." })
        output_file      = File.join(output_dir, filename)
        full_output_dir  = File.join(base_dir, output_dir)
        full_output_file = File.join(full_output_dir, filename)
        
        # check if the output_dir already exists.
        # is the dirname from the full output
        File.makedirs(full_output_dir) unless File.directory?(full_output_dir)
        
        # write the file to disk
        File.open(File.join(full_output_file), 'wb') do |f|
          f.write(instance.file.read)
        end
        
        Rails.logger.debug "[Storage] saving file to #{full_output_file}"
        save_attachment_info output_file
        run_processors
      end
      
      # Save the attachment info to the AR instance
      def save_attachment_info(path)
        instance.class.update_all(
          ["attachment_size = ?, attachment_path = ?, attachment_content_type = ?", file.size, path, file.content_type],
          ["id = ?", instance.id]
        )
      end
      
      private
        # The original file name. Used on interpolation
        def name
          file.original_filename
        end
      
        # The file content type. Used to save attachment info
        def content_type
          unless file.content_type.blank?
            file.content_type
          else
            "application/octet-stream"
          end
        end
      
        # The file name without the extension. Used on interpolation
        def base_name
          name.gsub(Regexp.new("\.#{extension}$"), "")
        end
      
        # The extension without dot. Used on interpolation
        def extension
          File.extname(name).gsub(/^\./sim, "")
        end
      
        # The storage name. Used on interpolation
        def storage_name
          instance_class.tableize
        end
      
        # Replace the :name pattern in the given string
        def interpolate(string)
          string = string.dup
        
          string.gsub!(/:([a-z0-9_]+)/sim) do |matches|
            _, placeholder = $~.to_a

            case placeholder
              when "rails_root"   then RAILS_ROOT
              when "base_name"    then base_name
              when "name"         then name
              when "extension"    then extension
              when "storage_name" then storage_name
              when "hash"         then
                Digest::SHA1.hexdigest("#{Time.now.utc}#{storage_name}#{instance.id}")
              else
                instance.send(placeholder).to_s
            end
          end
        
          string
        end
      
        # Return the AR instance class name
        def instance_class
          instance.class.name.to_s
        end
      
        # Wrapper to the upload file
        def file
          instance.file
        end
      
        # Retrieve the current partition and increment the storage
        def retrieve_storage_slot
          # if storage hasn't been created, start a new one
          unless storage
            # create storage if doesn't exists
            @storage = Storage.create({
              :name => instance_class, 
              :cluster => Array.new(instance.storage_settings[:depth], 1).join("/")
            })
          end
        
          # last part of cluster info is the file counter
          cluster_parts = storage.cluster.split("/")
          cluster_parts.pop
        
          # convert directory names to correspondent hex
          # example: 1/1/160 will be saved as 1/1/A0
          cluster_parts.collect!{|dir| ("%x" % dir.to_i).upcase } if instance.storage_settings[:hex]
        
          # join all cluster parts
          cluster_dirs = cluster_parts.join("/")
        
          # full cluster for later iteration and return
          cluster = storage.cluster
        
          # setting base directory
          base_dir     = interpolate(instance.storage_settings[:base_dir])
        
          # try to add a new cluster directory by default
          add_cluster = true

          # iterate reversed cluster array
          storage.cluster = storage.cluster.split("/").reverse.collect do |c|
            c = c.to_i

            # create a new cluster
            if add_cluster
              # if cluster is full, create a new one
              if c == instance.storage_settings[:max_items]
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

          # save the next iteration on this storage
          storage.save
        
          # return the current cluster dir
          [base_dir, cluster_dirs]
        end
      
        def run_processors
          [instance.storage_settings[:processor]].flatten.compact.each do |name|
            klass = SimplesIdeias::Storages::Processor.const_get(name.to_s.classify) rescue nil
            next unless klass
            
            klass.new(self).run
          end
        end
      end
  end
end