require 'rss'
require 'textmood'
require 'open-uri'
require 'x'
require 'date'
require 'active_support/all'

X_CREDENTIALS = {
  api_key: ENV['X_API_KEY'],
  api_key_secret: ENV['X_API_KEY_SECRET'],
  access_token: ENV['X_ACCESS_TOKEN'],
  access_token_secret: ENV['X_ACCESS_TOKEN_SECRET']
}.freeze

def post_tweet(tweet)
  @x_client ||= X::Client.new(**X_CREDENTIALS)
  @x_client.post('tweets', "{\"text\":\"#{tweet}\"}")
end

def tm
  @tm ||= TextMood.new(language: 'es')
end

def prepare
  @filtered_news = []
  @discarded_news = []

  if ENV['NEWS_RSS_SOURCES'].nil? || ENV['MOOD_THRESHOLD'].nil? || ENV['PERIODICITY'].nil?
    puts 'Please set the NEWS_RSS_SOURCES and MOOD_THRESHOLD and PERIODICITY environment variables.'
    exit
  end

  @news_rss_sources = ENV['NEWS_RSS_SOURCES'].split(',')
  @mood_threshold = ENV['MOOD_THRESHOLD'].to_f
  @excluded_categories = ENV['EXCLUDED_CATEGORIES'].split(',') || []
  @periodicity = ENV['PERIODICITY'].to_i
end

class NewsItem
  attr_accessor :title, :category, :link, :pub_date, :mood

  def initialize(title, category, link, pub_date, mood)
    @title = title
    @mood = mood
    @category = category
    @link = link
    @pub_date = pub_date
  end
end

def process_news
  @news_rss_sources.each do |url|
    URI.open(url) do |rss|
      feed = RSS::Parser.parse(rss, validate: false)
      feed.items.each do |item|
        mood = tm.analyze(item.title)

        item = NewsItem.new(item.title, item.category, item.link, item.pubDate, mood)

        if mood < @mood_threshold || @excluded_categories.include?(item.category)
          @discarded_news << item
        else
          @filtered_news << item
        end
      end
    end
  end
end

def publish_news
  puts "Item to publish: #{@filtered_news.length}"
  @filtered_news.sort { |a, b| a.pub_date <=> b.pub_date }.each do |item|
    post_tweet(item.title)
  end
end

def run
  prepare
  process_news
  publish_news if ENV['PUBLISH_NEWS'] == 'true'
end

run
