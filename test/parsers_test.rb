
require File.join(File.dirname(__FILE__), 'test_helper')

class ParserTestBase < Test::Unit::TestCase
  
  # Column1 Column2 Column3 Column4 Column5 Column6
  # 1 2 4 8 16  Text
  # 2 4 8 16  32  314159
  # 3 6 12  24  48  Caractères “accentués”
  # 4 8 16  32  64  21,00%
  # 5 10  20  40  80  1.000.000,00 €
  
  def assert_expected_result(rows)
    assert_equal [nil, "Column1", "Column2", "Column3", "Column4", "Column5", "Column6"],                rows[0][0,7]
    assert_equal [nil, "1",       "2",        "4",      "8",       "16",      "Text"   ],                rows[1][0,7]
    assert_equal [nil, "2",       "4",        "8",      "16",       "32",     "314159"],                 rows[2][0,7]
    assert_equal [nil, "3",       "6",        "12",      "24",       "48",    "Caractères “accentués”"], rows[3][0,7]
    assert_equal [nil, "4",       "8",        "16",      "32",       "64",    "21,00%"],                 rows[4][0,7]
    assert_equal [nil, "5",       "10",        "20",     "40",       "80",    "1.000.000,00 €"],         rows[5][0,7]
    assert_equal [nil, nil,       nil,        nil,       nil,        nil,      nil],                     rows[6][0,7]
  end
  
  def test_dummy
  end
  
end


class CsvParserTest < ParserTestBase

  def setup
    @parser = ActiveSheet::CsvParser.new 
  end
  
  def test_load
    assert_expected_result(@parser.load(fixture('parser_test_utf8')))
  end
  
  def test_parse
    assert_expected_result(@parser.parse(fixture_data('parser_test_utf8')))
  end
  
  
end

if ActiveSheet.const_defined?('FasterCsvParser')

  class FasterCsvParserTest < ParserTestBase

    def setup
      @parser = ActiveSheet::FasterCsvParser.new 
    end
  
    def test_load
      assert_expected_result(@parser.load(fixture('parser_test_utf8')))
    end
  
    def test_parse
      assert_expected_result(@parser.parse(fixture_data('parser_test_utf8')))
    end

  end

end # FasterCsvParser

if ActiveSheet.const_defined?('ExcelParser')

  # class ExcelCsvParserTest < ParserTestBase
  # 
  #     def setup
  #       @parser = ActiveSheet::ExcelParser.new 
  #     end
  #   
  #     def test_load
  #       assert_expected_result(@parser.load(fixture('parser_test', :xls)))
  #     end
  #   
  #     def test_parse
  #       assert_expected_result(@parser.parse(fixture_data('parser_test', :xls)))
  #     end
  # 
  #   end

end # ExcelParser

class FixedWidthParserTest < ParserTestBase

  def setup
    @parser = ActiveSheet::FixedWidthParser.new 
  end
  
  def test_should_fail_if_no_widths_option_given
    assert_raise(ArgumentError) { @parser.load(fixture('fixed_width_data', :txt)) }
    assert_raise(ArgumentError) { @parser.parse(fixture_data('fixed_width_data', :txt)) }
  end
  
  def test_load
    assert_expected_result @parser.load(fixture('fixed_width_data', :txt), :widths => [10, 10, 10, 10])
  end
  
  def test_parse
    assert_expected_result @parser.parse(fixture_data('fixed_width_data', :txt), :widths => [10, 10, 10, 10])
  end
  
  def assert_expected_result(rows)
    assert_equal 5, rows.size
    assert_equal ['1234567890', '1234567890', '1234567890', '1234567890'], rows[0]
    assert_equal ['ONE', 'TWO', 'THREE', 'FOUR'], rows[1]
    assert_equal ['', 'TWO', '', 'FOUR'], rows[2]
    assert_equal ['', '', '', ''], rows[3]
    assert_equal ['ONE', 'TWO', 'THREE', 'FOUR'], rows[4]
  end
  

end