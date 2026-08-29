class DropProductExceptions < ActiveRecord::Migration[8.1]
  def up
    drop_table :product_exceptions
  end

  def down
    create_table :product_exceptions do |t|
      t.references :product,        null: false, foreign_key: true
      t.date       :date,           null: false
      t.integer    :exception_type, null: false, default: 0
      t.integer    :batch_size
      t.time       :ready_time_override
      t.timestamps
    end
    add_index :product_exceptions, %i[product_id date], unique: true
  end
end
