require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'test/unit'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'eventmachine'
require 'strand'

class Test::Unit::TestCase

  def self.test(name, &block)
    name = "test_#{name}" unless name[0,5] == "test_"
    define_method(name) do
      EM.run do
        Fiber.new do
          instance_eval(&block)
          EM.stop
        end.resume
      end
    end
  end

end
