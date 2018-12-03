# == Schema Information
#
# Table name: markets
#
#  id         :integer          not null, primary key
#  base_unit  :string
#  quote_unit :string
#  sequence   :integer
#  source     :string
#  type       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Bittrex < Market
  def get_ticker
    ticker_url = 'https://bittrex.com/api/v1.1/public/getticker'
    res = Faraday.get do |req|
      req.url ticker_url
      req.params['market'] = "#{base_unit}-#{quote_unit}"
    end
    current = JSON.parse(res.body)
    current['result']
  end

  def get_market
    market_url = 'https://bittrex.com/api/v1.1/public/getmarketsummary'
    res = Faraday.get do |req|
      req.url market_url
      req.params['market'] = "#{base_unit}-#{quote_unit}"
    end
    current = JSON.parse(res.body)
    current['result'][0]
  end

  def get_market_history
    history_url = 'https://bittrex.com/api/v1.1/public/getmarkethistory'
    res = Faraday.get do |req|
      req.url history_url
      req.params['market'] = "#{base_unit}-#{quote_unit}"
    end
    current = JSON.parse(res.body)
    binding.pry
    current['result']
  end

  def generate_quote
    t = get_ticker
    ticker = {}
    ticker[:o] = last_quote&.c || t['Last']
    ticker[:h] = t['Ask']
    ticker[:l] = t['Bid']
    ticker[:c] = t['Last']
    ticker[:v] = (rand * 50).to_d.round(4)
    ticker[:t] = Time.now.to_i
    ticker
    candles.create(ticker)
  end
end
