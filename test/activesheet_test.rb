
require File.join(File.dirname(__FILE__), 'test_helper')

#
# Definitions
#

class NoDefinitions < ActiveSheet::Row
end

class DefinitionsToBeReset < ActiveSheet::Row
  columns :firstname, :lastname
end

class AllStringsColumns < ActiveSheet::Row
  
  columns :firstname, :lastname, :date_of_birth, :height, :weight
  
end

class ColumnsDefinedWithHash < ActiveSheet::Row
  
  # Not working with Ruby 1.8.x
  columns :firstname => :string, :lastname => :string, :date_of_birth => :date, :height => :integer, :weight => :float
  
end

class ManualColumnDefinitionsWithoutHeader < ActiveSheet::Row
  
  column [:firstname, :lastname], :string
  column :date_of_birth, :date
  column :height, :integer
  column :weight, :float
  
end

class ManualColumnDefinitionsWithSkipHeader < ActiveSheet::Row
  
  skip_header
  
  column [:firstname, :lastname], :string
  column :date_of_birth, :date
  column :height, :integer
  column :weight, :float
  
end

class ManualColumnDefinitionsWithStartAtLine < ActiveSheet::Row
  
  start_at_line 2
  
  column [:firstname, :lastname], :string
  column :date_of_birth, :date
  column :height, :integer
  column :weight, :float
  
end

class ColumnDiscovery < ActiveSheet::Row
  
  discover_columns
  
end

class ColumnDiscoveryWithHints < ActiveSheet::Row
  
  discover_columns "lastname" => :surname,
                   "date of birth" => [:birthdate, :date],
                   "height" => [:height, :integer],
                   :weight => :float

end

class GarbageProcessor < ActiveSheet::Row
  
  discover_columns :money1 => :decimal, :money2 => :decimal
  
  blank_cell %r{^(\#+|\-)$}
  
  # "1,000,000.00 USD"
  sanitize :money1 do |s| s.gsub(/[^\d\.]/, '') end
  
  # "$2.000.000,00"
  sanitize :money2 do |s| s.gsub(/[^\d,]/, '').tr(',', '.') end
  
end

class GarbageProcessorWithBlankCellAsBlock < ActiveSheet::Row
  
  discover_columns
  
  blank_cell do |s|
    (s.size == 0) || (s =~ /#+/)
  end
  
end

class CharsetConversionWithDefaultTarget < ActiveSheet::Row
  
  columns :col1, :col2, :col3
  
  from_charset "ISO-8859-1"
  
end

class CharsetConversionWithTarget < ActiveSheet::Row
  
  columns :col1, :col2, :col3
  
  from_charset "UTF-8"
  to_charset   "ISO-8859-1"
  
end

class AllStringsColumnsWithFilters < ActiveSheet::Row
  
  columns :firstname, :lastname, :date_of_birth, :height, :weight
  
  filter_source_row do |source_row|
    source_row[0] =~ /^J/i
  end

  filter_row do |row|
    row.lastname !~ /^doe$/i
  end
  
end


#
# Test
#

class ActiveSheetTest < Test::Unit::TestCase

  def test_load_failure_if_there_are_no_definitions
    assert_raise(ActiveSheet::MissingColumnDefinition) {
        NoDefinitions.load(fixture('no_header'))
    }
  end

  def test_definition_of_all_string_columns
    coldefs = AllStringsColumns.column_definitions
    assert coldefs.all? { |cd| cd.is_a?(ActiveSheet::StringColumn) }
  end

  def test_column_definition_with_columns_and_a_hash
    # Can't wait for Ruby 1.9 for this to work
    #assert_expected_column_definitions(ColumnsDefinedWithHash.column_definitions)
  end

  def test_definition_of_columns_one_column_at_a_time
    assert_expected_column_definitions(ManualColumnDefinitionsWithoutHeader.column_definitions)
  end
  
  def test_reset_column_definition
    assert DefinitionsToBeReset.column_definitions
    assert DefinitionsToBeReset.column_definitions.any?
    DefinitionsToBeReset.reset_column_definitions
    assert_nil DefinitionsToBeReset.column_definitions
  end

  def test_column_discovery
    ColumnDiscovery.reset_column_definitions
    ColumnDiscovery.load(fixture('header'))
    coldefs = ColumnDiscovery.column_definitions
    assert_equal 5, coldefs.size
    assert_coldef :firstname,     :string, coldefs[0]
    assert_coldef :lastname,      :string, coldefs[1]
    assert_coldef :date_of_birth, :string, coldefs[2]
    assert_coldef :height,        :string, coldefs[3]
    assert_coldef :weight,        :string, coldefs[4]
  end

  def test_column_discovery_with_hints
    ColumnDiscoveryWithHints.load(fixture('header'))
    coldefs = ColumnDiscoveryWithHints.column_definitions
    assert_equal 5, coldefs.size
    assert_coldef :firstname, :string,  coldefs[0]
    assert_coldef :surname,   :string,  coldefs[1]
    assert_coldef :birthdate, :date,    coldefs[2]
    assert_coldef :height,    :integer, coldefs[3]
    assert_coldef :weight,    :float,   coldefs[4]
  end
  
  def test_column_name_inflection
    assert_raise(ActiveSheet::ColumnDefinitionError) {
      ActiveSheet::Row.send(:string_to_column_symbol, "")
    }
    assert_equal :firstname,      ActiveSheet::Row.send(:string_to_column_symbol, "firstname")
    assert_equal :middle_initial, ActiveSheet::Row.send(:string_to_column_symbol, "middle initial")
    assert_equal :Pr_nom,         ActiveSheet::Row.send(:string_to_column_symbol, "PrÃ©nom")
    assert_equal :_123_FOUR,      ActiveSheet::Row.send(:string_to_column_symbol, "123-FOUR")
  end
  
  def test_record_initialization_with_autodiscovery
    rows = ColumnDiscovery.load(fixture('header'))
    assert_equal 3, rows.size
    row = rows.first
    assert_equal "John", row.firstname
    assert_equal "Doe", row.lastname
    assert_equal "1985-08-01", row.date_of_birth
    assert_equal "178", row.height
    assert_equal "85.4", row.weight
  end
  
  def test_record_initialization_with_autodiscovery_and_hints
    rows = ColumnDiscoveryWithHints.load(fixture('header'))
    assert_equal 3, rows.size
    row = rows.first
    assert_equal "John", row.firstname
    assert_equal "Doe", row.surname
    assert_equal Date.civil(1985,8,1), row.birthdate
    assert_equal 178, row.height
    assert_equal 85.4, row.weight
  end
  
  def test_attributes
    rows = ColumnDiscovery.load(fixture('header'))
    h = rows.first.attributes
    assert_kind_of Hash, h
    assert h.any?
    assert ColumnDiscovery.column_definitions.all? { |cd| h.has_key?(cd.name) }
  end
  
  def test_start_at_line
    rows = ManualColumnDefinitionsWithStartAtLine.load(fixture('no_header'))
    assert_equal 2, rows.first.line_number
    assert_equal "Jane", rows.first.firstname
  end
  
  def test_stop_after_line
  end
  
  def test_blank_cell_with_regular_expression
    rows = GarbageProcessor.load(fixture('garbage'))
    assert_nil rows.first.empty1
    assert_nil rows.first.empty2
  end

  def test_blank_cell_with_regular_with_block
    rows = GarbageProcessorWithBlankCellAsBlock.load(fixture('garbage'))
    assert_equal "-", rows.first.empty1
    assert_nil        rows.first.empty2
    assert_nil        rows.first.empty3
  end
  
  def test_sanitize
    rows = GarbageProcessor.load(fixture('garbage'))
    assert_equal BigDecimal("1000000.00"), rows.first.money1
    assert_equal BigDecimal("2000000.00"), rows.first.money2
  end
  
  def test_works_with_incomplete_rows_when_not_using_conversions
    rows = AllStringsColumns.load(fixture("header_with_incomplete_rows"))
    #Jane,Foo-Bar,"","",61.2
    assert_equal "", rows[2].date_of_birth
    assert_equal "", rows[2].height
    #,,,,    
    assert_nil rows[3].firstname
    assert_nil rows[3].lastname
    assert_nil rows[3].date_of_birth
    assert_nil rows[3].height
    assert_nil rows[3].weight
  end
  
  def test_works_with_incomplete_rows
    rows = ManualColumnDefinitionsWithSkipHeader.load(fixture("header_with_incomplete_rows"))
    #Jane,Foo-Bar,"","",61.2
    assert_nil rows[1].date_of_birth
    assert_nil rows[1].height
    #,,,,
    assert_nil rows[2].firstname
    assert_nil rows[2].lastname
    assert_nil rows[2].date_of_birth
    assert_nil rows[2].height
    assert_nil rows[2].weight
  end
  
  def test_charset_conversion_with_default_target
    row = CharsetConversionWithDefaultTarget.parse("Caractères,,Spéciaux").first
    assert_equal "CaractÃ¨res", row.col1
    assert_nil   row.col2
    assert_equal "SpÃ©ciaux", row.col3
  end
  
  def test_charset_conversion_with_custom_target
    row = CharsetConversionWithTarget.parse("CaractÃ¨res,,SpÃ©ciaux").first
    assert_equal "Caractères", row.col1
    assert_nil   row.col2
    assert_equal "Spéciaux", row.col3
  end
  
  def test_row_filters
    rows = AllStringsColumnsWithFilters.load(fixture("no_header"))
    assert_equal 1, rows.size
    assert_equal "Jane", rows.first.firstname
  end
  
  protected
  
  def assert_coldef(name, coltype, coldef)
    assert_equal name, coldef.name, "Column definition name mismatch, expected '#{name}' and got '#{coldef.name}'"
    assert_equal coltype, coldef.class.name.split('::').last.gsub(/Column$/, '').downcase.to_sym
  end
  
  # 
  def assert_expected_column_definitions(coldefs)
    assert_equal 5, coldefs.size
    assert_coldef :firstname, :string, coldefs[0]
    assert_coldef :lastname, :string, coldefs[1]
    assert_coldef :date_of_birth, :date, coldefs[2]
    assert_coldef :height, :integer, coldefs[3]
    assert_coldef :weight, :float, coldefs[4]
  end
  
  
end