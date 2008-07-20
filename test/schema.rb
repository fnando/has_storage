ActiveRecord::Schema.define(:version => 0) do
  create_table :users do |t|
    t.string :name
  end
  
  create_table :storages do |t|
    t.string :name, :cluster
  end
end