class Flight < ApplicationRecord
	validates :flight_number, :uniqueness => { :scope => :departure_time,
    :message => "already saved" }
  validates :route_id, presence: true
  belongs_to :route
  has_many :flight_prices

  def self.create_or_find_flight(route_id,flight_number,departure_time,airline_code,airplane_type)
    is_flight_exist = Flight.find_by(flight_number:flight_number,departure_time:departure_time)
    if is_flight_exist.nil?
      begin
        stored_flight = Flight.create(route_id: "#{route_id}", flight_number:"#{flight_number}", departure_time:"#{departure_time}", airline_code:"#{airline_code}", airplane_type: "#{airplane_type}")
        flight_id = stored_flight.id
      rescue
        flight_id = is_flight_exist.id
      end
    else
      flight_id = is_flight_exist.id
    end
  end

  def self.update_best_price(origin,destination,date) 
    route = Route.find_by(origin:"#{origin}",destination:"#{destination}")
    flights = route.flights.where(departure_time: date.to_datetime.beginning_of_day.to_s..date.to_datetime.end_of_day.to_s)
    flights.each do |flight|
      stored_flight_prices = flight.flight_prices.select("price,supplier").order("price").first
        if stored_flight_prices.nil? 
          flight.best_price = 0 #means the flight is no longer available
        else
          flight.best_price = stored_flight_prices.price 
          flight.price_by = stored_flight_prices.supplier 
        end
        flight.save()
      end
  end

  def get_lowest_price_collection(origin,destination)
      route = Route.find_by(origin:origin, destination:destination)
      dates = {today: Date.today.to_s, tomorrow: (Date.today+1).to_s, dayaftertomorrow: (Date.today+2).to_s}
      prices = {today: '', tomorrow: '', dayaftertomorrow: ''}

      dates.each do |title,date|
        prices[title.to_sym] = get_lowest_price(route,date)
      end
      
      prices
  end

  def get_lowest_price_time_table(origin,destination,date)

      route = Route.find_by(origin:origin, destination:destination)
      if date.to_date == Date.today
        starting_date = date
      elsif date.to_date == (Date.today+1)
        starting_date = (date.to_date-1).to_s
      else
        starting_date = (date.to_date-2).to_s
      end
      
      prices = Hash.new()
      dates = [(starting_date.to_date).to_s, (starting_date.to_date+1).to_s, (starting_date.to_date+2).to_s, (starting_date.to_date+3).to_s, (starting_date.to_date+4).to_s]
      dates.each do |date|
        prices[date.to_sym] =  get_lowest_price(route,date)
      end
      prices

  end

  def get_lowest_price(route,date)
      flight = route.flights.where(departure_time: date.to_datetime.beginning_of_day.to_s..date.to_datetime.end_of_day.to_s).where.not(best_price:0).sort_by(&:best_price).first
      flight
  end

  def airline_call_sign(airline_code)
  airlines ={"W5"=>"IRM",
    "AK"=>"ATR", 
      "B9"=>"IRB", 
      "sepahan"=>"SON", 
      "hesa"=>"SON",  
      "I3"=>"TBZ", 
      "JI"=>"MRJ", 
      "IV"=>"CPN", 
      "NV"=>"IRG", 
      "saha"=>"IRZ", 
      "ZV"=>"IZG",
      "HH"=>"TBN",
      "QB"=>"QSM" ,
      "Y9"=>"KIS",
      "EP"=>"IRC",
      "IR"=>"IRA",
      "SR"=>"SHI"
    }
  airlines[airline_code].nil? ? airline_code : airlines[airline_code]
  end

  def flight_list(route,date)
    flight_list = route.flights.where(departure_time: date.to_datetime.beginning_of_day.to_s..date.to_datetime.end_of_day.to_s).where.not(best_price:0)
    flight_list.each do |flight|
       if flight.airplane_type.empty?
         airline_code = flight.airline_code.upcase
         call_sign = flight.flight_number.upcase.sub airline_code, airline_call_sign(airline_code)
         airplane_type = FlightDetail.find_by(call_sign: call_sign)
         flight.airplane_type = airplane_type.airplane_type unless airplane_type.nil?
       end
     end
    flight_list = flight_list.sort_by(&:best_price)
  end

end