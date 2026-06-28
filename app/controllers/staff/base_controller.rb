module Staff
  class BaseController < ApplicationController
    layout "staff"
    before_action :require_staff!
  end
end
