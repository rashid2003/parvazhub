# frozen_string_literal: true

class User < ApplicationRecord
  enum channel: %i[website telegram app]
  enum role: %i[admin user]
  after_initialize :set_default_role, if: :new_record?

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  validates :telegram_id, uniqueness: true, allow_blank: true
  has_many :user_search_histories, dependent: :destroy
  has_many :user_flight_price_histories, dependent: :destroy
  has_many :telegram_search_queries, class_name: 'Telegram::SearchQuery', dependent: :destroy
  has_many :redirects
  has_many :reviews

  def set_default_role
    self.role ||= :user
  end

  def create_or_find_user_by_id(args)
    user = User.find_by(id: args[:user_id])
    user = create_guest_user(channel: args[:channel]) if user.nil?
    user
  end

  def create_or_find_user_by_telegram(args)
    user = User.find_by(telegram_id: args[:telegram_id])
    if user.nil?
      user = create_guest_user(channel: args[:channel],
                               telegram_id: args[:telegram_id],
                               first_name: args[:first_name],
                               last_name: args[:last_name])
    end
    user
  end

  def last_searches
    search_histories = user_search_histories.order('created_at DESC').limit(10)
    routes = {}
    unless search_histories.empty?
      search_histories.each do |search_history|
        route_id = search_history.route_id
        date =  search_history.departure_time
        if routes[route_id.to_s.to_sym].nil?
          routes[route_id.to_s.to_sym] = [date]
        else
          unless routes[route_id.to_s.to_sym].include? date
            routes[route_id.to_s.to_sym] << date
          end
        end
      end
    end
    add_hash_names routes
    # example of output [{route_id: 1, dates: ["2017-01-12","2018-01-20"]}, {route_id: 1, dates: ["2017-01-12","2018-01-20"]}]
  end

  def last_searches_without_past_dates
    searches = last_searches
    searches.each do |search|
      fileterd_dates = []
      search[:dates].each do |date|
        fileterd_dates << date if date.to_date > Date.today - 1
      end
      if fileterd_dates.empty?
        fileterd_dates << (Date.today + 1).to_s
      end # add one date at least
      search[:dates] = fileterd_dates
    end
    searches
  end

  private

  def add_hash_names(routes)
    results = []
    routes.keys.each do |route|
      results << { route_id: route.to_s, dates: routes[route] }
    end
    results
  end

  def create_guest_user(args)
    user = User.create(email: "guest_#{Time.now.to_i}#{rand(100)}@parvazhub.com",
                       telegram_id: args[:telegram_id],
                       channel: args[:channel],
                       password: password,
                       first_name: args[:first_name],
                       last_name: args[:last_name])
  end

  def password
    password = (0...8).map { rand(65..90).chr }.join
  end
end
