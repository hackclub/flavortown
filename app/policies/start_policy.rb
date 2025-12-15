# frozen_string_literal: true

class StartPolicy < ApplicationPolicy
  def index?
    !logged_in?
  end
end
