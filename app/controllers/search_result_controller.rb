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
    if params[:date] == "today"
      date = Date.today.to_s
    elsif params[:date] == "tomorrow"
      date = (Date.today+1).to_s
    else
      date = params[:date]
    end

    origin_code = City.get_city_code_based_on_english_name origin_name
    destination_code = City.get_city_code_based_on_english_name destination_name
    route = Route.find_by(origin:"#{origin_code}", destination:"#{destination_code}")

    if route.nil?
      notfound
    else
      search_suppliers(route,date,"website",request.user_agent)
      index(route,origin_name,origin_code,destination_name,destination_code,date)
    end 
  end

  def search_suppliers(route,date,channel,request)
    unless (["Googlebot","yandex","MJ12bot","Baiduspider"].any? {|word| request.include? word})
      telegram = Telegram::Monitoring.new
      telegram.send({text:"👊 [#{Rails.env}] #{route.id}, #{date} \n #{request}"})
      UserSearchHistory.create(route_id:route.id,departure_time:"#{date}",channel:channel) #save user search to show in admin panel      
   end
    response_available = SearchHistory.where(route_id:route.id,departure_time:"#{date}").where('created_at >= ?', allow_response_time(date).to_f.minutes.ago).count
    SupplierSearch.new.search(route.origin,route.destination,date,20,"user") if response_available == 0
  end

  def allow_response_time(date)
    if date == Date.today.to_s #today
      allow_time = 10
    elsif date == (Date.today+1).to_s #tomorrow
      allow_time = 20
    elsif date == (Date.today+2).to_s #day after
      allow_time = 60
    elsif date == (Date.today+3).to_s #rest 1
      allow_time = 120
    elsif date == (Date.today+4).to_s #rest 2
      allow_time = 120
    elsif date == (Date.today+5).to_s #rest 3
      allow_time = 120
    elsif date == (Date.today+6).to_s #rest 4
      allow_time = 120
    else
      allow_time = 1440
    end
    return allow_time
  end

  def notfound
    @default_destination_city = City.default_destination_city
    @cities = City.list 
    render :notfound
  end

  def index(route,origin_name,origin_code,destination_name,destination_code,date)
     @flights = Flight.new.flight_list(route,date)
     date_in_human = date.to_date.to_parsi.strftime '%A %d %B'     
     @search_parameter ={origin_name: origin_name, origin_code: origin_code, destination_code: destination_code, destination_name: destination_name,date: date, date_in_human: date_in_human}
     @cities = City.list 

     render :index
  end

  def flight_prices
    @dates = Array.new
    @prices = Array.new
    flight_id = params[:id]
    flight_date = Flight.find(flight_id).departure_time.to_date.to_s
    @flight_prices = FlightPrice.where(flight_id: params[:id]).order(:price)
    @flight_price_over_time = FlightPriceArchive.flight_price_over_time(flight_id,flight_date)
    @flight_price_over_time.each do |date,price|
      @dates <<  date.to_s.to_date.to_parsi.strftime("%A %d %B")
      @prices << price
    end
    
    respond_to do |format|
        format.js 
        format.html
    end
  end

end