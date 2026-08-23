class AddEndDateToStoreExceptions < ActiveRecord::Migration[8.1]
  def change
    remove_index :store_exceptions, :date

    rename_column :store_exceptions, :date, :start_date
    add_column    :store_exceptions, :end_date, :date

    add_index :store_exceptions, [:start_date, :end_date], unique: true
  end
end
