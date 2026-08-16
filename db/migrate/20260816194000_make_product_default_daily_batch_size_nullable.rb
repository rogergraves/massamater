class MakeProductDefaultDailyBatchSizeNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :products, :default_daily_batch_size, true
  end
end
