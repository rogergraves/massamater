class CreateDailyInventories < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_inventories do |t|
      t.references :product,             null: false, foreign_key: true
      t.date       :date,                null: false
      t.integer    :batch_size,          null: false
      t.time       :ready_time_override
      t.boolean    :skipped,             null: false, default: false
      t.boolean    :added,               null: false, default: false

      t.timestamps
    end

    add_index :daily_inventories, [:product_id, :date], unique: true
  end
end
