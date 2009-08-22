
require 'test/unit'

$: << File.dirname(__FILE__) + '/../lib'
require 'activesheet'

class Test::Unit::TestCase
  
  def fixture(name, format = :csv)
    File.join(File.dirname(__FILE__), "fixtures/#{name}.#{format}")
  end
  
  def fixture_data(name, format = :csv)
    File.read(fixture(name, format))
  end
  
end