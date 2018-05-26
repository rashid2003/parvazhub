class SearchResultController < ApplicationController
  
  def flight_search
    origin = params[:search][:origin].downcase
    destination = params[:search][:destination].downcase
    date = params[:search][:date]

    redirect_to  action: 'search', origin_name: origin, destination_name: destination, date: date
  end

  def search 
    origin_name = params[:origin_name].downcase
    destination_name = params[:destination_name].downcase
    date = date_to_code params[:date]
    channel = "website"
    route = Route.new.get_route_by_english_name(origin_name,destination_name)
    user = get_current_user(channel, request.user_agent) 

    if date < Date.today.to_s 
        redirect_to  action: 'search', origin_name: origin_name, destination_name: destination_name, date: "today"
        return
    end

    if route.nil? 
        notfound
    else 
        flights = get_flight_results({route:route, date: date, channel:"website", user_agent_request: request.user_agent, user: user})
        index(route,date,flights)
    end
  end

  def get_flight_results args
    #args = {route,date,channel,user_agent_request,user}
    if is_bot(args[:user_agent_request])
      # do not search supplier, just get results from db
      flights = get_flights(args[:date], args[:route],true)
    else
      search_background_archive args
      flights = get_flights(args[:date],args[:route],false)
    end
    return flights
  end

  def notfound
    render :notfound
  end

  def index(route,date,flights)
    @flights = flights
    origin = City.find_by(city_code: route.origin)
    destination = City.find_by(city_code: route.destination)
    date_in_human = date_to_human date    
    @search_parameter ={origin_english_name: origin.english_name, origin_persian_name: origin.persian_name, origin_code: origin.city_code,
                            destination_english_name: destination.english_name, destination_persian_name: destination.persian_name, destination_code: destination.city_code,
                            date: date, date_in_human: date_in_human, international: route.international}
    @route_days = RouteDay.week_days(origin.city_code,destination.city_code)
        
    if date <= Date.today.to_s
      @flight_dates = Flight.new.get_lowest_price_timetable(origin.city_code,destination.city_code,Date.today.to_s)
    else
      @flight_dates = Flight.new.get_lowest_price_timetable(origin.city_code,destination.city_code,date)
    end   
    @is_mobile = browser.device.mobile?    
    @prices = Flight.new.get_lowest_price_for_a_month(origin.city_code, destination.city_code, Date.today)

    render :index
  end

  def flight_prices
    origin_name = params[:origin_name].downcase
    destination_name = params[:destination_name].downcase
    date = params[:date]
    flight_id = params[:id]
    channel = "website"
    @dates = Array.new
    @prices = Array.new

    origin = City.find_by(english_name: origin_name.downcase) 
    destination = City.find_by(english_name: destination_name.downcase)

    date_in_human = date_to_human date #date.to_date.to_parsi.strftime '%A %d %B'   
    @flight = Flight.find(flight_id)
    @user = get_current_user(channel, nil) 
    @search_parameter ={origin_english_name: origin.english_name, origin_persian_name: origin.persian_name, origin_code: origin.city_code,
                        destination_english_name: destination.english_name, destination_persian_name: destination.persian_name, destination_code: destination.city_code,
                        date: date, date_in_human: date_in_human}
    
    @flight_prices = get_flight_price(@flight,channel,request.user_agent, current_user)
    @flight_price_over_time = FlightPriceArchive.flight_price_over_time(flight_id,date)
    @flight_price_over_time.each do |date,price|
        @dates <<  date.to_s.to_date.to_parsi.strftime("%A %d %B")
        @prices << price
    end
    
    @airline = Airline.find_by(code: @flight.airline_code.split(",").first) 
    @reviews = get_reviews @airline
  
    render :flight_price
  end

  def get_flight_price(flight,channel,user_agent_request,user)
    flight_price_background_archive(channel,flight,user)  unless is_bot(user_agent_request)
    FlightResult.new.get_flight_price(flight)
  end

  private

  def search_background_archive args
    if Rails.env.production?
      UserSearchHistoryWorker.perform_async(args[:route].id,args[:date],args[:channel],args[:user].id)
      AmplitudeWorker.perform_async(args[:user].id,"search",args[:channel])
    else
      UserSearchHistory.create(route_id: args[:route].id, departure_time: args[:date], channel: args[:channel], user: args[:user])
    end
  end

  def flight_price_background_archive channel,flight,user
    if Rails.env.production?
      UserFlightPriceHistoryWorker.perform_async(channel,flight.id,user.id) 
      AmplitudeWorker.perform_async(user.id,"supplierPage",channel)
    else
      UserFlightPriceHistory.create(flight_id: flight.id,channel: channel, user: user)
    end
  end

  def get_reviews airline
    if airline.nil?
      reviews = Array.new
    else
      reviews = Review.where(page: airline.english_name).where.not(text:"")
    end
  end

  def get_flights(date,route,is_bot)
    if is_bot
        FlightResult.new(route,date).get_archive
    else
        date >= Date.today.to_s ? FlightResult.new(route,date).get : Array.new
    end
  end

  def date_to_human date
    date = date.to_date
    if date == Date.today
      "امروز"
    elsif date == (Date.today+1) 
      "فردا"
    else
      date.to_date.to_parsi.strftime ' %-d %B' 
    end
  end

  def date_to_code date
    if date == "today"
      date = Date.today.to_s
    elsif date == "tomorrow"
      date = (Date.today+1).to_s
    else
      date = date
    end
  end

  def get_current_user(channel, user_agent_request) 
    user = automatic_login({channel: channel, user_agent_request: user_agent_request})
  end

      
end