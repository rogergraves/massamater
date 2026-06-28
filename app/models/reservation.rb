class Reservation < ApplicationRecord
  belongs_to :user
  has_many :reservation_items, dependent: :destroy
  has_many :products, through: :reservation_items

  enum :source, { sms: 0, whatsapp: 1, phone: 2, counter: 3, online: 4 }

  scope :active,    -> { where(cancelled: false) }
  scope :upcoming,  -> { active.where(collected_at: nil).where("date >= ?", Date.current) }
  scope :collected, -> { active.where.not(collected_at: nil) }

  validates :date,   presence: true
  validates :source, presence: true

  def collected?
    collected_at.present?
  end

  def cancellable?
    !collected? && !cancelled?
  end
end
