class User < ApplicationRecord
  has_secure_password validations: false

  has_many :reservations, dependent: :destroy

  enum :contact_channel, { sms: 0, whatsapp: 1 }, default: :sms

  validates :phone, presence: true,
                    uniqueness: true,
                    format: {
                      with: /\A\+[1-9]\d{6,14}\z/,
                      message: "must be in E.164 format (+country code)"
                    }
  validates :name, presence: true

  def staff?
    password_digest.present?
  end
end
