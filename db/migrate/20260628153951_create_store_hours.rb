class CreateStoreHours < ActiveRecord::Migration[8.1]
  def change
    create_table :store_hours do |t|
      t.integer :day_of_week, null: false
      t.boolean :open,        null: false, default: true
      t.time    :opens_at
      t.time    :closes_at

      t.timestamps
    end

    add_index :store_hours, :day_of_week, unique: true
  end
end
