# frozen_string_literal: true

class AddIndexToAirports < ActiveRecord::Migration[5.0]
  def change
    add_index :airports, [:iata_code], unique: true
  end
end
