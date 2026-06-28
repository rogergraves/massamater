class CreateReservationItems < ActiveRecord::Migration[8.1]
  def change
    create_table :reservation_items do |t|
      t.references :reservation, null: false, foreign_key: true
      t.references :product,     null: false, foreign_key: true
      t.integer    :quantity,    null: false

      t.timestamps
    end

    add_index :reservation_items, [:reservation_id, :product_id], unique: true
  end
end
