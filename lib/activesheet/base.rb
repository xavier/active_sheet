
module ActiveSheet
  
  VERSION = "0.0.2"
  DEFAULT_TARGET_ENCODING = 'UTF-8'  
    
  class Base

    attr_accessor :line_number
    
    class << self

      attr_accessor :column_definitions
      attr_accessor :reverse_index
      
      # Declare one or more columns, they must be of course in the same order as they appear in the spreadsheet.
      # Pass in a list of symbols to declare the columns with the defaul type <tt>:string</tt>
      # You can also pass in an <b>ordered</b> hash of <tt>:column_name => type</tt> pairs
      def columns(*symbols)
        if symbols.size == 1 && symbols.first.is_a?(Hash)
          symbols.first.each do |name, column_type|
            column(name, column_type)
          end
        else
          column(symbols)
        end
      end

      # Declare one or more columns of a certain type (default <tt>:string</tt>).
      # You can pass either one symbol or an array of symbols if you want to declare multiple columns in a row
      def column(symbols, column_type = :string, options = {})
        @column_definitions ||= []
        [symbols].flatten.each do |symbol|
          @column_definitions << make_column(symbol, column_type, options)
          attr_accessor symbol
        end
      end
      
      # Use the first row to be processed as column/attribute names
      # Each column name will be inflected by replacing all non alphanumerical ASCII characters by underscores 
      # (and prepending an underscore if the name starts with a number). all columns content will be treated as strings.
      # If you are not happy with the inflected column names or if you want to define the type of some columns, you can pass some hints.
      # * <tt>"Foo" => :bar</tt> will tell the inflector to use :bar as attribute name for column "Foo"
      # * <tt>"Foo" => [:bar, :integer]</tt> will tell the inflector to use :bar as attribute name for column "Foo" which will be treated as an :integer
      # * <tt>:foo => :date</tt> will tell the inflector that the type of the inflected column name :foo is :date
      # Supported types are: <tt>:string</tt> (default), <tt>:integer</tt>, <tt>:float</tt>, <tt>:decimal</tt>, <tt>:date</tt>, <tt>:time</tt>, <tt>:datetime</tt>
      def discover_columns(hints = {})
        @discover_columns = true
        process_hints(hints)
      end
      
      # Define the source charset (default: nil, no character encoding conversion will occur)
      # If you do not define a target encoding with <tt>to_charset</tt>, it will default to UTF-8
      def from_charset(encoding)
        @source_encoding = encoding
      end
      
      # Define a target to convert the incoming data to (default: UTF-8)
      # If you define a target encoding, you must define a source encoding
      def to_charset(encoding)
        @target_encoding = encoding
      end
      
      # You cannot use this method along with <tt>start_at_line</tt>
      def skip_header
        start_at_line(2)
      end
      
      # Start processing the file at the given line number (default: nil, process file from the first line)
      # You cannot use this method along with <tt>skip_header</tt>
      # If your model uses column autodiscovery, the first row processed will be treated as the header row.
      def start_at_line(number)
        @start_at_line = number
      end
      
      # Stop processing the file after the given line number (default: nil, process file until the end)
      def stop_after_line(number)
        @stop_after_line = number
      end
      
      # Extends the definition of a blank cell, either by providing a regular expression or a block
      # If your blank cell condition is met, the corresponding attribute will be nil.
      def blank_cell(regexp = nil, &block)
        if block_given? 
          if regexp
            raise ArgumentError.new("blank_cell accepts either a regular expression or a block, you cannot provide both")
          end
        else
          if !regexp
            raise ArgumentError.new("blank_cell requires either a regular expression or a block")
          end
        end
        if regexp
          @blank_cell = lambda { |s| s =~ regexp }
        else
          @blank_cell = block
        end
      end
      
      # Register a source row object filter.
      # The block will be called with a an array of strings, as returned by the parser
      def filter_source_row(&block)
        @filter_source_row = block
      end

      # Register a row object filter.
      # The block will be called with an instance of your ActiveSheet::Base subclass
      def filter_row(&block)
        @filter_row = block
      end
      
      # Declare a sanitizer block for the given column name.
      # The processor will pass in a string to the sanitizer before performing any column type specific conversion.
      def sanitize(column_name, &block)
        @sanitizers ||= {}
        @sanitizers[column_name] = block
      end
      
      # Returns an instance of parser for the given format.  Accepted formats are <tt>:csv</tt>, <tt>:xls</tt> or <tt>:fixed</tt>
      def select_parser(format)
        case format
        when :csv
          klass = ActiveSheet.const_defined?("FasterCsvParser") ? FasterCsvParser : CsvParser
          klass.new
        when :xls
          ExcelParser.new
        when :fixed
          FixedWidthParser.new
        else
          raise ArgumentError.new("Could not find parser for unknown format: #{format}")
        end
      end

      # The format will be guessed from the filename extension (.csv or .xls), 
      # you can also explicitly set the format using the :format option (see <tt>parse</tt> for the possible formats)
      # Options are passed to the parser, CSV parsers accept <tt>:field_separator</tt> and <tt>:row_separator</tt>
      def load(filename, options = {})
        if options[:format] || (ext = File.extname(filename)).empty?
          format = options[:format]
        else
          format = ext[1..-1].downcase.to_sym
        end
        parser = select_parser(format)
        process(parser.load(filename, options))
      end
      
      # Parse the given date as CSV, unless specified with the :format option.  Other options will be passed to the parser.
      # Accepted formats are <tt>:csv</tt>, <tt>:xls</tt> or <tt>:fixed</tt>
      # The <tt>:fixed</tt> format is for fixed width columns, you must provide a <tt>:widths</tt> with an array of number
      # giving the size (in number of bytes) of every column.  This does not play well with UTF8 and UNICODE contents but if
      # people send you content in fixed-width format, they are unlikely to know about multibyte character sets.
      def parse(data, options = {})
        format = options[:format] || :csv
        parser = select_parser(format)
        process(parser.parse(data, options))
      end
      
      protected
      
      #
      def reset_column_definitions
        @column_definitions = nil
      end
      
      def process_hints(hints)
        @name_hints = {}
        @type_hints = {}
        hints.each do |k, v|
          case k 
            when Symbol
              @type_hints[k] = v
            when String
              name_hint, type_hint = v
              @name_hints[k] = name_hint
              @type_hints[name_hint] = type_hint
            else
              raise ArgumentError.new("Unsupported hint key: #{k.inspect}")
          end
        end
      end
      
      def string_to_column_symbol(s)
        raise ArgumentError.new("Column name may not be blank -- You may have an empty cell in the header row") if s.nil?
        if @name_hints && (n = @name_hints[s])
          n
        elsif (s = s.gsub(/[^a-z_0-9]+/i, '_').gsub(/^(\d)/, '_\1')).empty?
          raise ColumnDefinitionError.new("Column name may not be blank")
        else
          s.downcase.to_sym
        end
      end
      
      def define_columns_from_row(row)
        row.each do |s|
          sym = string_to_column_symbol(s)
          column(sym, @type_hints[sym] || :string)
        end
      end
      
      # Returns a concrete column definition object 
      def make_column(name, column_type, options = {})
        ActiveSheet.const_get("#{column_type.to_s.capitalize}Column".to_sym).new(name, options)
      end
      
      # Returns a row instance, populated with the data from the CSV row
      def make_row(csv_row)
        obj = self.new
        obj.line_number = @line_number
        @column_definitions.each_with_index do |col, i|
          k = col.name
          if v = csv_row[i]
            v =  @iconv.iconv(v) if @iconv
            if blank_cell?(v) || col.consider_blank?(v)
              # 
              obj[k] = nil
            else
              # Convert after sanitization (when applicable) 
              obj[k] = col.value((s = @sanitizers[k]) ? s.call(v) : v)
            end
          else 
            obj[k] = nil
          end
        end
        obj
      end
      
      # Apply custom blankness verifications
      def blank_cell?(s)
        @blank_cell && @blank_cell.call(s)
      end
      
      # Ensures all instance variables are set before we start processing
      def initial_state_before_process(rows)
        @line_number = 0
        @start_at_line ||= 0
        @stop_after_line ||= rows.size
        @sanitizers ||= {}
        if @source_encoding
          @target_encoding ||= DEFAULT_TARGET_ENCODING
          @iconv = Iconv.open(@target_encoding, @source_encoding)
        else
          @iconv = nil
        end
      end
      
      # The main routine which converts raw rows into a collection of objects
      def process(rows)
        raise MissingColumnDefinition unless @discover_columns || @column_definitions
        initial_state_before_process(rows)
        result = Collection.new
        reset_column_definitions if discover = @discover_columns
        rows.each do |source_row|
          @line_number += 1
          # Line number filters
          next  if @line_number < @start_at_line
          break if @line_number > @stop_after_line
          #
          if discover
            define_columns_from_row(source_row)
            discover = false
          else
            # Filter on raw data
            next if @filter_source_row && !@filter_source_row.call(source_row)
            # Create object
            row = make_row(source_row)
            # Filter on processed object
            next if @filter_row && !@filter_row.call(row)
            result << row #unless skip_row?(row)
          end
        end
        result
      end
      
    end # class << self
    
    # Attribute accessor
    def [](k)
      send(k)
    end

    # Attribute accessor
    def []=(k, v)
      send("#{k}=".to_sym, v)
    end
    
    # Returns the column definitions for the row
    def column_definitions
      self.class.column_definitions
    end

    # Returns a hash with all attributes as {symbol => value}
    def attributes
      column_definitions.inject({}) { |h, col| h[col.name] = self[col.name]; h }
    end
    
  end
  
end