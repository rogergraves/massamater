class CreateProductScheduleDays < ActiveRecord::Migration[8.1]
  def change
    create_table :product_schedule_days do |t|
      t.references :product, null: false, foreign_key: true
      t.integer    :day_of_week, null: false

      t.timestamps
    end

    add_index :product_schedule_days, [:product_id, :day_of_week], unique: true
  end
end
