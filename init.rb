require "has_storage"
require "ftools"
require "digest/sha1"

ActiveRecord::Base.send(:include, SimplesIdeias::Storages)
require File.dirname(__FILE__) + "/lib/storage"
require File.dirname(__FILE__) + "/lib/attachment"
