require "rails_helper"

RSpec.describe "Staff::Products routing", type: :routing do
  it "routes GET /staff/products to staff/products#index" do
    expect(get: "/staff/products").to route_to("staff/products#index")
  end

  it "routes POST /staff/products to staff/products#create" do
    expect(post: "/staff/products").to route_to("staff/products#create")
  end

  it "routes PATCH /staff/products/1 to staff/products#update" do
    expect(patch: "/staff/products/1").to route_to("staff/products#update", id: "1")
  end

  it "routes DELETE /staff/products/1 to staff/products#destroy" do
    expect(delete: "/staff/products/1").to route_to("staff/products#destroy", id: "1")
  end
end
