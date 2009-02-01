require "has_storage"
require "ftools"

ActiveRecord::Base.send(:include, SimplesIdeias::Acts::Storages)
require File.dirname(__FILE__) + "/lib/storage"
