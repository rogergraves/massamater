class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string  :phone,           null: false
      t.string  :name,            null: false
      t.integer :contact_channel, null: false
      t.string  :password_digest

      t.timestamps
    end

    add_index :users, :phone, unique: true
  end
end
