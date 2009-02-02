ActiveRecord::Schema.define(:version => 0) do
  create_table :users do |t|
    t.string :name, :attachment_content_type, :attachment_path
    t.integer :attachment_size
  end
  
  create_table :storages do |t|
    t.string :name, :cluster
  end
end