
require File.join(File.dirname(__FILE__), 'test_helper')

class AbstractColumnTest < Test::Unit::TestCase

  def setup
    @class_name = self.class.name.gsub(/Test$/, '').to_sym
    @col_class = ActiveSheet.const_get(@class_name)
    @col = @col_class.new(:column)
  end
  
  def test_type
      assert_equal @class_name.to_s, @col.class.name.split('::').last
  end

  def test_value
    assert_raise(NotImplementedError) { @col.value('') }
  end
  
end

class StringColumnTest < AbstractColumnTest
  
  def test_value
    assert "", @col.value("")
    assert "abc", @col.value("abc")
  end
  
end

class IntegerColumnTest < AbstractColumnTest
  
  def test_value
    assert_equal 1,    @col.value('1')
    assert_equal -123, @col.value('-123')
    assert_equal 0,    @col.value('X')
  end
  
end

class FloatColumnTest < AbstractColumnTest

  def test_value
    assert_equal 1.0,      @col.value('1')
    assert_equal -3.14159, @col.value('-3.14159')
    assert_equal 0.0,      @col.value('X')
  end

end

class DecimalColumnTest < AbstractColumnTest

  def test_value
    assert_equal 1.0,                    @col.value('1')
    assert_equal BigDecimal("-3.14159"), @col.value('-3.14159')
    assert_equal BigDecimal("0.0"),      @col.value('X')
  end  
  
end

class DateColumnTest < AbstractColumnTest

  def test_value
    assert_equal Date.civil(1985, 8, 1), @col.value("1985-08-01")
  end  
  
end

class TimeColumnTest < AbstractColumnTest

  def test_value
   t = @col.value("12:34")
   assert_equal [12, 34], [t.hour, t.min]
   t = @col.value("12:34:56")
   assert_equal [12, 34, 56], [t.hour, t.min, t.sec]
   t = @col.value("3PM")
   assert_equal [15, 00, 00], [t.hour, t.min, t.sec]
  end  
  
end

class DatetimeColumnTest < AbstractColumnTest

  def test_value
    dt = @col.value("1985-08-01 12:34:56")
    assert_equal 1985, dt.year
    assert_equal 8, dt.month
    assert_equal 1, dt.day
    assert_equal 12, dt.hour
    assert_equal 34, dt.min
    assert_equal 56, dt.sec
  end  
  
end

