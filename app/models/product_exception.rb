class ProductException < ApplicationRecord
  belongs_to :product

  validates :date,       presence: true, uniqueness: { scope: :product_id }
  validates :batch_size, numericality: { only_integer: true, greater_than_or_equal_to: 1 },
                         allow_nil: true
  validates :batch_size, presence: true, if: :added?

  def effective_ready_time
    ready_time_override || product.default_ready_time
  end

  def exception_summary
    if skipped?
      I18n.t("staff.inventory.exceptions.type_skip")
    else
      parts = []
      parts << I18n.t("staff.inventory.exceptions.qty_summary", qty: batch_size) if batch_size.present?
      parts << ready_time_override.strftime("%H:%M") if ready_time_override.present?
      prefix = added? ? "#{I18n.t('staff.inventory.exceptions.type_add')} — " : ""
      "#{prefix}#{parts.join(', ')}"
    end
  end
end
