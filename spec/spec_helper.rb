require 'eventmachine'
require 'strand'
require 'bundler'
Bundler.require(:development)

require 'support/scratch'
require 'support/fixtures'


RSpec.configure do |config|
  config.mock_with :rr
end

require "strand/atc"
Atc = Strand::Atc

require "em-spec/rspec"
