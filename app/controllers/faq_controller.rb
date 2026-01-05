class FaqController < ApplicationController
  def index
    authorize :faq, :index?
  end
end
