class DailyInventory < ApplicationRecord
  belongs_to :product

  validates :date,       presence: true, uniqueness: { scope: :product_id }
  validates :batch_size, numericality: { greater_than_or_equal_to: 0 }

  def effective_ready_time
    ready_time_override || product.default_ready_time
  end

  def self.for_product_on(product, date)
    find_or_initialize_by(product: product, date: date) do |inv|
      inv.batch_size = product.default_daily_batch_size
    end
  end
end
