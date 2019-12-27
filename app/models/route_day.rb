# frozen_string_literal: true

class RouteDay < ApplicationRecord
  validates :route_id, uniqueness: { scope: :day_code,
                                     message: 'already exist' }
  belongs_to :route

  def calculate_all
    Route.all.each do |route|
      days_available = inspect_days(route.id)
      import(days_available, route.id)
    end
  end

  def inspect_days(route_id)
    days = []
    flight_details = FlightDetail.where(route_id: route_id)
    flight_details&.each do |flight_detail|
      day_index = flight_detail.departure_time.to_date.wday
      days.push day_index unless days.include? day_index
    end
    days
  end

  def import(days_available, route_id)
    days_available.each do |day|
      RouteDay.create(route_id: route_id, day_code: day)
    end
  end

  def self.week_days(origin, destination)
    days = []
    route = Route.find_by(origin: origin, destination: destination)
    route_days = RouteDay.where(route: route.id)
    route_days.each do |route_day|
      days.push route_day.day_code
    end
    days
  end
end
