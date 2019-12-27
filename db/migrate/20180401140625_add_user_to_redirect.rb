# frozen_string_literal: true

class AddUserToRedirect < ActiveRecord::Migration[5.0]
  def change
    add_reference :redirects, :user, index: true, foreign_key: true
  end
end
