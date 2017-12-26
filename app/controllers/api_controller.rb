class ApiController < ApplicationController
    
    def city_prefetch_suggestion
      city_list = Array.new
      country_list = Country.select(:country_code,:persian_name,:english_name).all.to_a
      #cities = City.where(country_code: "IR").order(:priority)
      cities = City.where("priority <?",100).order("priority")
    
      cities.each do |city|
        country_object = country_list.detect {|c| c.country_code == city.country_code}
        country_value = country_object.persian_name.nil? ? country_object.english_name : country_object.persian_name
        city_list << {'code': city.english_name, 'value': city.persian_name, 'country': country_value}
      end
      render json: city_list  
    end
    
    def city_suggestion 
      query = params[:query].downcase
      city_list = Array.new
      country_list = Country.select(:country_code,:persian_name,:english_name).all.to_a

      cities = City.where("english_name LIKE ? OR persian_name LIKE ?","%#{query}%","%#{query}%").order(:priority)
      cities.each do |city|
        persian_name = city.persian_name
        english_name = city.english_name
        country_object = country_list.detect {|c| c.country_code == city.country_code}
            
        city_value = city.persian_name.nil? ? english_name : persian_name
        country_value = country_object.persian_name.nil? ? country_object.english_name : country_object.persian_name

        city_list << {'code': english_name, 'value': city_value , 'country': country_value}
      end
      render json: city_list  
    end

    def service_test
      sql = "Select 1 from countries"
      status = ActiveRecord::Base.connection.execute(sql)
      if status
        render json: {
            status: 200
        }.to_json
      end
    end

    def flights
      channel, user_agent_request = "app"
      date = search_params[:date]
      route = get_route search_params[:origin_name], search_params[:destination_name] 
      search_params = 

      if route and date_is_valid(date)
        body = get_flights(route, date,channel,user_agent_request) 
        status = true  
      else 
        body = "Aamoo ina chi chie mifresi? "
        body += "Date is invalid. Correct date format contract: 2017-01-01." unless date_is_valid(date)
        body += "City codes are invalid. Correct origin and destination format contract: tehran or mashhad." unless route
        status = false
      end
      render json: {status: status, search_params: api_search_params(route,date), body: body}
    end

    def api_search_params route,date
      unless route.nil?
        origin =  City.find_by(city_code: route.origin)
        destination =  City.find_by(city_code: route.destination)
        {
          origin_persian_name: origin.persian_name,
          destination_persian_name: destination.persian_name,
          date: date
        }
      end
    end

    def suppliers
        channel, user_agent_request = "app"
        flight = Flight.find_by_id(flight_price_params[:id])
  
        if flight
          body = get_flight_price(channel,flight,user_agent_request)
          status = true  
        else 
          body = "Halo vajebe ba ee parvazoo beri? "
          body += "Flight ID is invalid or out of date or sold out." unless flight
          status = false
        end
        render json: {status: status, body: body}
      end
  
  private
    def get_flight_price(channel,flight,request_user_agent)
      text = "✌️ [#{Rails.env}] #{flight.id} \n #{request_user_agent}"
      UserFlightPriceHistoryWorker.perform_async(channel,text,flight.id)
      result_time_to_live = FlightResult.allow_response_time(flight.departure_time.to_date.to_s)
      results = FlightPrice.new.get_flight_price(flight.id,result_time_to_live)
      return results
    end

    def date_is_valid date
      begin
        date_array = date.split('-').map(&:to_i)
        if Date.valid_date? date_array[0], date_array[1], date_array[2]
          return true
        else
          return false
        end
      rescue
      end
    end

    def get_route origin_name, destination_name
      route = Route.new.get_route_by_english_name(origin_name,destination_name)
    end

    def get_flights(route,date,channel,user_agent_request)
      text = "☝️ [#{Rails.env}] #{route.id}, #{date} \n #{user_agent_request}"
      UserSearchHistoryWorker.perform_async(text,route.id,date,channel)
      flights = FlightResult.new(route,date).get
    end

    def search_params
      params.permit(:origin_name,:destination_name,:date)
    end

    def flight_price_params
      params.permit(:id)
    end

end
