class CreateReservations < ActiveRecord::Migration[8.1]
  def change
    create_table :reservations do |t|
      t.references :user,       null: false, foreign_key: true
      t.date       :date,       null: false
      t.time       :pickup_time
      t.text       :note
      t.integer    :source,     null: false
      t.datetime   :collected_at
      t.boolean    :cancelled,  null: false, default: false

      t.timestamps
    end
  end
end
