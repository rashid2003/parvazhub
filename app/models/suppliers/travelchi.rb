class Suppliers::Travelchi
  require "uri"
  require "rest-client"

  def search(origin,destination,date,search_history_id)
      proxy_url = nil
      if Rails.env.test?
        response = File.read("test/fixtures/files/domestic-travelchi.log") 
        return {response: response}
      end

      begin
        url = "http://api.chartex.ir/api/v1/flights/search"
        date = date + "T04:30:00+04:30"  
        body = {"flight_date":date.to_time.to_i,"source":"#{origin.upcase}","destination":"#{destination.upcase}","provider_code":"FOROUD","scope":"local","adults":1,"childs":0,"infant":0}
        ActiveRecord::Base.connection_pool.with_connection do        
          SearchHistory.append_status(search_history_id,"R1(#{Time.now.strftime('%M:%S')})")
          proxy_url = Proxy.new_proxy
        end
        response = RestClient::Request.execute(method: :post, url: "#{URI.parse(url)}", payload: body.to_json, headers: {:'Authorization'=> "JWT #{get_auth_key}",:'Content-Type'=> "application/json",:'Connection'=>"keep-alive",:'User-Agent'=>"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.81 Safari/537.36"},proxy: proxy_url)
      rescue => e
        ActiveRecord::Base.connection_pool.with_connection do 
          Proxy.set_status(proxy_url,"deactive") unless proxy_url.nil?
          SearchHistory.append_status(search_history_id,"failed:(#{Time.now.strftime('%M:%S')}) #{e.message}")
        end
          return {status:false, response: e.message}
      end
      return {status:true,response: response.body}
    end

    def import_domestic_flights(response,route_id,origin,destination,date,search_history_id)
      flight_id = nil
      flight_prices = Array.new()
      json_response = JSON.parse(response[:response])
      ActiveRecord::Base.connection_pool.with_connection do
        SearchHistory.append_status(search_history_id,"Extracting(#{Time.now.strftime('%M:%S')})")
      end
      
      json_response.each do |flight|
        airline_code = get_airline_code(flight["airline"])
        next if airline_code.nil?
        flight_number = airline_code + flight_number_correction(flight["flight_num"],airline_code)
        departure_time = date + " " + flight["departs"][0..1] + ":" + flight["departs"][2..3] + ":00"
        airplane_type = ""
        price = get_price(flight["classes"])
        next if price.nil?
        deeplink_url = get_deep_link(origin,destination,date)
        ActiveRecord::Base.connection_pool.with_connection do
          flight_id = Flight.create_or_find_flight(route_id,flight_number,departure_time,airline_code,airplane_type)
        end

        #to prevent duplicate flight prices we compare flight prices before insert into database
        flight_price_so_far = flight_prices.select {|flight_price| flight_price.flight_id == flight_id}
        unless flight_price_so_far.empty? #check to see a flight price for given flight is exists
          if flight_price_so_far.first.price.to_i <= price.to_i #saved price is cheaper or equal to new price so we dont touch it
            next
          else
            flight_price_so_far.first.price = price #new price is cheaper, so update the old price and go to next price
            next
          end
        end

        ActiveRecord::Base.connection_pool.with_connection do
          flight_prices << FlightPrice.new(flight_id: "#{flight_id}", price: "#{price}", supplier:"travelchi", flight_date:"#{date}", deep_link:"#{deeplink_url}" )
        end

      end #end of each loop
      
      unless flight_prices.empty?
        ActiveRecord::Base.connection_pool.with_connection do
          #SearchHistory.append_status(search_history_id,"Deleting(#{Time.now.strftime('%M:%S')})")
          #first we should remove the old flight price archive 
          FlightPrice.delete_old_flight_prices("travelchi",route_id,date)
          #SearchHistory.append_status(search_history_id,"Importing(#{Time.now.strftime('%M:%S')})")
          #then bulk import enabled by a bulk import gem
          FlightPrice.import flight_prices
          #SearchHistory.append_status(search_history_id,"Archive(#{Time.now.strftime('%M:%S')})") 
          FlightPriceArchive.import flight_prices
          SearchHistory.append_status(search_history_id,"Success(#{Time.now.strftime('%M:%S')})")
        end
      else
        ActiveRecord::Base.connection_pool.with_connection do
          SearchHistory.append_status(search_history_id,"empty response(#{Time.now.strftime('%M:%S')})")
        end
      end

  end
  
  def get_auth_key
    keys =[
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJwYyI6IiIsImMiOiJJUlIiLCJyb2xlIjoiR1VFU1QiLCJhZCI6MTcsImV4cCI6MTUwNTMwNzA1NiwiaWF0IjoxNTAyNzE1MDU2LCJuYmYiOjE1MDI3MTUwNTYsImlkIjoyNn0.Y9yKGBagCK8UFKK739J-vD9XE-lYroEXMzxVLUq6T7Q",
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJwYyI6IiIsImMiOiJJUlIiLCJyb2xlIjoiR1VFU1QiLCJhZCI6MTcsImV4cCI6MTUwNTMwMjk3OCwiaWF0IjoxNTAyNzEwOTc4LCJuYmYiOjE1MDI3MTA5NzgsImlkIjoyNn0.EKiD0K_3KRvBSJ_58BDuNrkMjW4YJVF6-3-YG0dIas4",
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJwYyI6IiIsImMiOiJJUlIiLCJyb2xlIjoiR1VFU1QiLCJhZCI6MTcsImV4cCI6MTUwNTMwNzE3NCwiaWF0IjoxNTAyNzE1MTc0LCJuYmYiOjE1MDI3MTUxNzQsImlkIjoyNn0.pp1kR-wwCkW4Py4CwVj22Mt-XvLPEf6xEHd-obrGa64",
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJwYyI6IiIsImMiOiJJUlIiLCJyb2xlIjoiR1VFU1QiLCJhZCI6MTcsImV4cCI6MTUwNTMwNzIxNiwiaWF0IjoxNTAyNzE1MjE2LCJuYmYiOjE1MDI3MTUyMTYsImlkIjoyNn0.Ds9Cxk7hJ8wMJ3d-m_-VgvGk2y0GB5AUIVfZ-coAxxU",
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJwYyI6IiIsImMiOiJJUlIiLCJyb2xlIjoiR1VFU1QiLCJhZCI6MTcsImV4cCI6MTUwNTMwNzI2NywiaWF0IjoxNTAyNzE1MjY3LCJuYmYiOjE1MDI3MTUyNjcsImlkIjoyNn0.fHhXQWo0Zp-QRyReEfWQUtza9a3SkJExoWp9NNrjBAI"
        ]
    return keys[rand(0..4)]
  end
  
  def flight_number_correction(flight_number,airline_code)
    flight_number = flight_number.sub(airline_code,"")  if flight_number.include? airline_code
    return flight_number.gsub(/[^\d,\.]/, '')        
  end

  def get_airline_code(airline_code)
    airlines ={
      "SA"=>"SE",
      "ATR"=>"AK",
      "RZ"=>"SE"
		}
	airlines[airline_code].nil? ? airline_code : airlines[airline_code]
  end

  def get_price(prices)
    best_price = 0
    prices.each do |price|
      next if price["remain"] == 0 
      best_price = price["fee"] if best_price == 0
      best_price = price["fee"] if price["fee"] < best_price
    end
    if best_price == 0
      return nil
    else
      return (best_price/10).to_i
    end
  end
  
  def get_deep_link(origin,destination,date)
    date = date.to_date.to_parsi.to_s.gsub("-","/")
    link = "http://travelchi.ir/%D9%86%D8%AA%D8%A7%DB%8C%D8%AC-%D8%AC%D8%B3%D8%AA%D8%AC%D9%88-%D9%BE%D8%B1%D9%88%D8%A7%D8%B2/?search_type=flights&ajax=1&From=-#{origin.upcase}&To=-#{destination.upcase}&AdultCount=1&ChildCount=0&InfantCount=0&FlightDate=#{date}&scope=local"
  end 

end