class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string  :name,                               null: false
      t.string  :name_en
      t.time    :default_ready_time,                 null: false
      t.integer :default_daily_batch_size,           null: false
      t.integer :max_reservable_quantity_per_client
      t.boolean :active,                             null: false, default: true
      t.integer :order,                              null: false, default: 0

      t.timestamps
    end
  end
end
