class CreateStoreExceptions < ActiveRecord::Migration[8.1]
  def change
    create_table :store_exceptions do |t|
      t.date    :date,   null: false
      t.boolean :closed, null: false, default: true
      t.time    :opens_at
      t.time    :closes_at
      t.string  :reason, null: false

      t.timestamps
    end

    add_index :store_exceptions, :date, unique: true
  end
end
