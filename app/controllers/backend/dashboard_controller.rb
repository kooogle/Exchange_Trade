class Backend::DashboardController < Backend::BaseController
  skip_load_and_authorize_resource

  def index
    sta_time = params[:start] || (Date.current - 1.days).to_s
    @market = Market.find(params[:market]) rescue nil || Market.first
    tickers = @market.candles.where("ts >= ?",sta_time.to_time)
    tickers = @market.candles.last(192) if tickers.count < 96
    @price_array = tickers.map {|x| [x.ms_t,x.c] }
    @decimal = Market.calc_decimal tickers.last.c rescue 2
  end
end