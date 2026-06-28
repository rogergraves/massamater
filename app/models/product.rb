class Product < ApplicationRecord
  has_many :product_schedule_days, dependent: :destroy
  has_many :daily_inventories,     dependent: :destroy
  has_many :reservation_items,     dependent: :restrict_with_error

  has_one_attached :photo
  has_one_attached :icon

  scope :active,  -> { where(active: true) }
  scope :ordered, -> { order(:order, :name) }

  validates :name,                     presence: true
  validates :default_ready_time,       presence: true
  validates :default_daily_batch_size, numericality: { only_integer: true, greater_than: 0 }
  validates :max_reservable_quantity_per_client,
            numericality: { greater_than: 0, allow_nil: true }

  def display_name
    (I18n.locale == :en && name_en.present?) ? name_en : name
  end
end
