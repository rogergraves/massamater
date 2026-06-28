# Staff user — phone: +351912000001, password: password
User.find_or_create_by!(phone: "+351912000001") do |u|
  u.name            = "Staff"
  u.contact_channel = :sms
  u.password        = "password"
end

# Weekly store hours
# 0=Sunday 1=Monday 2=Tuesday 3=Wednesday 4=Thursday 5=Friday 6=Saturday
[
  { day_of_week: :sunday,    open: false },
  { day_of_week: :monday,    open: false },
  { day_of_week: :tuesday,   open: true, opens_at: "08:00", closes_at: "18:00" },
  { day_of_week: :wednesday, open: true, opens_at: "08:00", closes_at: "18:00" },
  { day_of_week: :thursday,  open: true, opens_at: "08:00", closes_at: "18:00" },
  { day_of_week: :friday,    open: true, opens_at: "08:00", closes_at: "18:00" },
  { day_of_week: :saturday,  open: true, opens_at: "09:00", closes_at: "15:00" },
].each do |attrs|
  StoreHour.find_or_create_by!(day_of_week: attrs[:day_of_week]) do |sh|
    sh.open      = attrs[:open]
    sh.opens_at  = attrs[:opens_at]
    sh.closes_at = attrs[:closes_at]
  end
end

# Sample products
[
  {
    name: "Baguete", name_en: "Baguette",
    default_ready_time: "08:00", default_daily_batch_size: 20,
    max_reservable_quantity_per_client: 4, active: true, order: 1,
    days: %i[tuesday wednesday thursday friday saturday]
  },
  {
    name: "Broa de Milho", name_en: "Corn Bread",
    default_ready_time: "09:00", default_daily_batch_size: 12,
    max_reservable_quantity_per_client: 2, active: true, order: 2,
    days: %i[tuesday wednesday thursday friday saturday]
  },
  {
    name: "Cinnamon Rolls", name_en: "Cinnamon Rolls",
    default_ready_time: "10:00", default_daily_batch_size: 10,
    max_reservable_quantity_per_client: 4, active: true, order: 3,
    days: %i[friday saturday]
  },
  {
    name: "Granola", name_en: "Granola",
    default_ready_time: "08:00", default_daily_batch_size: 15,
    max_reservable_quantity_per_client: nil, active: true, order: 4,
    days: %i[thursday friday saturday]
  },
  {
    name: "Bolachas", name_en: "Cookies",
    default_ready_time: "09:00", default_daily_batch_size: 24,
    max_reservable_quantity_per_client: 6, active: false, order: 5,
    days: %i[tuesday wednesday thursday friday]
  },
].each do |attrs|
  days = attrs.delete(:days)
  product = Product.find_or_create_by!(name: attrs[:name]) do |p|
    p.assign_attributes(attrs)
  end
  days.each { |day| product.product_schedule_days.find_or_create_by!(day_of_week: day) }
end

puts "Seeded: 1 staff user, 7 store hours, #{Product.count} products"
