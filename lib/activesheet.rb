
require 'csv'
require 'date'
require 'iconv'
require 'bigdecimal'

require 'activesheet/common'
require 'activesheet/parsers'
require 'activesheet/columns'
require 'activesheet/base'

# module ActiveSheet
#   
#   class Error < StandardError ; end
#   class MissingColumnDefinition < Error ; end
#   class ColumnDefinitionError < Error ; end
#   
#   #
#   #
#   #
#   
#   class Collection < Array
#     
#     # If you have ActiveSupport loaded, you can use Rails index_by
#     def build_index(symbol = nil, &block)
#       if block_given?
#         f = lambda { |row, h| h[(yield row)] = row; h }
#       else
#         f = lambda { |row, h| h[row.send(symbol)] = row; h }
#       end
#       self.inject({}, f)
#     end
#     
#   end
#   
#   #
#   # Columns
#   #
#   
#   class AbstractColumn
#     
#     attr_accessor :name
#     
#     def initialize(name, options = {})
#       @name    = name
#       @options = options
#       process_options
#     end
#     
#     def process_options
#     end
#     
#     # Returns the actual value for the cell -- Implemented in concret column classes
#     def value(s)
#       raise NotImplementedError
#     end
#     
#   end
#   
#   class StringColumn < AbstractColumn
#     
#     def value(s)
#       s
#     end
#     
#   end
# 
#   class IntegerColumn < AbstractColumn
#     
#     def process_options
#       @allow_blank = @options[:allow_blank]
#     end
#     
#     def value(s)
#       s.to_i
#     end
#     
#   end
#   
#   class DecimalColumn < AbstractColumn
#     
#     def value(s)
#       BigDecimal(s)
#     end
#     
#   end
# 
#   class FloatColumn < AbstractColumn
#     
#     def value(s)
#       s.to_f
#     end
#     
#   end
# 
#   class DateColumn < AbstractColumn
#     
#     def value(s)
#       Date.parse(s)
#     end
#     
#   end
# 
#   class TimeColumn < AbstractColumn
#     
#     def value(s)
#       Time.strptime(s)
#     end
#     
#   end
# 
#   class DatetimeColumn < AbstractColumn
#     
#     def value(s)
#       DateTime.parse(s)
#     end
#     
#   end
#     
#   #
#   #
#   #
#   
#   class Row
#     
#     def initialize
#     end
# 
#     attr_accessor :line_number
#     
#     class << self
# 
#       attr_accessor :column_definitions
#       attr_accessor :reverse_index
#       
#       #
#       def columns(*symbols)
#         if symbols.size == 1 && symbols.first.is_a?(Hash)
#           symbols.first.each do |name, column_type|
#             column(name, column_type)
#           end
#         else
#           column(symbols)
#         end
#       end
# 
#       #
#       def column(symbols, column_type = :string, options = {})
#         @column_definitions ||= []
#         @reverse_index ||= {}
#         [symbols].flatten.each do |symbol|
#           @reverse_index[symbol] = @column_definitions.size
#           @column_definitions << make_column(symbol, column_type, options)
#           attr_accessor symbol
#         end
#       end
#       
#       #
#       def discover_columns(hints = {})
#         @discover_columns = true
#         process_hints(hints)
#       end
#       
#       #
#       def source_encoding(encoding)
#         @source_encoding = encoding
#       end
#       
#       def skip_header
#         start_at_line(2)
#       end
#       
#       def start_at_line(number)
#         @start_at_line = number
#       end
# 
#       #
#       def load(filename)
#         raise MissingColumnDefinition unless @discover_columns || @column_definitions
#         @line_number = 0
#         @start_at_line ||= 0
#         rows = Collection.new
#         CSV.open(filename, 'r').each do |csv_row|
#           @line_number += 1
#           next if @line_number < @start_at_line
#           if @discover_columns
#             define_columns_from_csv_row(csv_row)
#             @discover_columns = false
#           else
#             row = make_row(csv_row)
#             rows << row #unless skip_row?(row)
#           end
#         end
#         rows
#       end
#       
#       # TODO
#       # def inspect
#       # end
#       
#       protected
#       
#       def process_hints(hints)
#         @name_hints = {}
#         @type_hints = {}
#         hints.each do |k, v|
#           case k 
#             when Symbol
#               @type_hints[k] = v
#             when String
#               name_hint, type_hint = v
#               @name_hints[k] = name_hint
#               @type_hints[name_hint] = type_hint
#             else
#               raise ArgumentError.new("Unsupported hint key: #{k.inspect}")
#           end
#         end
#       end
#       
#       def column_symbol_from_string(s)
#         if @name_hints && (n = @name_hints[s])
#           n
#         elsif (s = s.gsub(/[^a-z_0-9]+/i, '_').gsub(/^(\d)/, '_\1')).empty?
#           raise ColumnDefinitionError.new("Column name may not be blank")
#         else
#           s.to_sym
#         end
#       end
#       
#       def define_columns_from_csv_row(row)
#         row.each do |s|
#           sym = column_symbol_from_string(s)
#           column(sym, @type_hints[sym] || :string)
#         end
#       end
#       
#       # Returns a concrete column definition object 
#       def make_column(name, column_type, options = {})
#         ActiveSheet.const_get("#{column_type.to_s.capitalize}Column".to_sym).new(name, options)
#       end
#       
#       # Returns a row instance, populated with the data from the CSV row
#       def make_row(csv_row)
#         obj = self.new
#         obj.line_number = @line_number
#         @column_definitions.each_with_index do |col, i|
#           obj[col.name] = col.value(csv_row[i])
#         end
#         obj
#       end
# 
#     end # class << self
#     
#     # Implement this to filter out
#     def skip_csv_row?(csv_row)
#       false
#     end
#     
#     def skip_row?(row)
#       false
#     end
#     
#     def [](k)
#       send(k)
#     end
# 
#     def []=(k, v)
#       send("#{k}=".to_sym, v)
#     end
#     
#     def column_definitions
#       self.class.column_definitions
#     end
# 
#     def attributes
#       column_definitions.inject({}) { |h, col| h[col.name] = self[col.name]; h }
#     end
#     
#   end
#     
# end