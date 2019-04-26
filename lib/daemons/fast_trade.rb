#!/usr/bin/env ruby

# You might want to change this
ENV["RAILS_ENV"] ||= "production"

root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

$running = true
Signal.trap("TERM") do
  $running = false
end

def start_trading
  if current_fast_order
    sell_trade_order
  else
    buy_trade_order if order_cooling?
  end
end

def support_level
  $market.regulate.support
end

def current_fast_order
  $market.bids.fast_order.succ.first
end

def order_cooling?
  (Time.now - $market.asks.fast_order.succ.last.created_at) > 7.minute rescue true
end

def trade_cash
  $market.regulate&.fast_cash
end

def buy_trade_order
  tickers_30m = $market.get_ticker('3m', 11)
  price_30m = tickers_30m.map { |x| x[4].to_f }
  extent = price_30m.last / price_30m.first
  kline = tickers_30m.tickers_to_kline
  down_entity = kline.select {|x| x[1] < 0 }
  up_entity = kline.select {|x| x[1] > 0 }
  recent_price = $market.recent_price
  market_index = $market.market_index('3m', 40)[4]

  if recent_price < $market.min_16 * 1.075 && recent_price > $market.min_16
    amount = trade_cash / recent_price
    $market.new_bid(recent_price, amount, 'fast')
  end

  if (extent < 0.99 && market_index > 0.6) || (extent < 0.975 && market_index < 0.6)
    $market.sync_cash
    if $market.cash.balance > trade_price
      if down_entity.size < 5
        trade_price = recent_price * 0.998
        amount = trade_cash / trade_price
        $market.new_bid(trade_price, amount, 'fast')

      elsif down_entity.size == 5
        trade_price = recent_price * 0.9985
        amount = trade_cash / trade_price
        $market.new_bid(trade_price, amount, 'fast')

      elsif [6,7].include? down_entity.size
        trade_price = recent_price * 0.997
        amount = trade_cash / trade_price
        $market.new_bid(trade_price, amount, 'fast')

      elsif down_entity.size == 8
        trade_price = recent_price * 0.996
        amount = trade_cash / trade_price
        $market.new_bid(trade_price, amount, 'fast')
      end
    end
  end

end

def fast_profit
  $market.regulate&.fast_profit || 1.02
end

def sell_trade_order
  order = current_fast_order
  order_price = order.price
  amount = order.amount

  if Time.now - order.created_at > 5.minute
    tickers_15m = $market.get_ticker('3m', 5)
    recent_price = $market.recent_price
    kline = tickers_15m.tickers_to_kline
    down_entity = kline.select {|x| x[1] < 0 }
    up_entity = kline.select {|x| x[1] > 0 }
    market_index = $market.market_index('5m', 30)[4]

    if recent_price > order_price
      if kline[-1][1] < 0 && recent_price > order_price * fast_profit
        sell_order(order, recent_price, amount)
      elsif recent_price > order_price * 1.02
        sell_order(order, recent_price , amount)
      end
    end

    if recent_price < order_price
      if market_index > 0.6 && recent_price < order_price * 0.985 && order_price * amount < trade_cash * 1.25
        expansion = trade_cash / recent_price / 10
        expansion_order = $market.new_bid(recent_price, expansion)
        if expansion_order.state.succ?
          order.update(amount: amount + expansion_order.amount)
          expansion_order.update(state: 120)
        end
      end

      if recent_price < order_price * 997 && market_index < 0.6
        sell_order(order, recent_price , amount)
        $market.regulate.update(fast_trade: false)
      end
    end

  end
end

def sell_order(order, recent_price, amount)
  ask_order = $market.new_ask(recent_price, amount, 'fast')
  if ask_order.state.succ?
    order.update_attributes(state: 120)
    order.sold_tip_with(ask_order)
  end
end

while $running
  begin
    Market.seq.includes(:regulate).each do |item|
      $market = item
      if item.regulate&.fast_trade
        start_trading
      end
    end
  rescue => detail
    Notice.dingding("快频交易错误提醒：\n 交易对：#{$market.symbols} \n #{detail.message} \n #{detail.backtrace[0..2].join("\n")}")
  end
  sleep 45
end
