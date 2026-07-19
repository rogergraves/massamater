class RenameDailyInventoriesToProductExceptions < ActiveRecord::Migration[8.1]
  def change
    rename_table :daily_inventories, :product_exceptions
    change_column_null :product_exceptions, :batch_size, true
    change_column_default :product_exceptions, :batch_size, nil
  end
end
