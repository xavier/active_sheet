
module ActiveSheet
    
  DEFAULT_TARGET_ENCODING = 'UTF-8'  
    
  class Row

    attr_accessor :line_number
    
    class << self

      attr_accessor :column_definitions
      attr_accessor :reverse_index
      
      #
      def reset_column_definitions
        @column_definitions = nil
      end
      
      #
      def columns(*symbols)
        if symbols.size == 1 && symbols.first.is_a?(Hash)
          symbols.first.each do |name, column_type|
            column(name, column_type)
          end
        else
          column(symbols)
        end
      end

      #
      def column(symbols, column_type = :string, options = {})
        @column_definitions ||= []
        [symbols].flatten.each do |symbol|
          @column_definitions << make_column(symbol, column_type, options)
          attr_accessor symbol
        end
      end
      
      #
      def discover_columns(hints = {})
        @discover_columns = true
        process_hints(hints)
      end
      
      # TODO
      def from_charset(encoding)
        @source_encoding = encoding
      end
      
      # TODO
      def to_charset(encoding)
        @target_encoding = encoding
      end
      
      #
      def skip_header
        start_at_line(2)
      end
      
      #
      def start_at_line(number)
        @start_at_line = number
      end
      
      #
      def stop_after_line(number)
        @stop_after_line = number
      end
      
      #
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
      
      def filter_source_row(&block)
        @filter_source_row = block
      end

      def filter_row(&block)
        @filter_row = block
      end
      
      #
      def sanitize(column_name, &block)
        @sanitizers ||= {}
        @sanitizers[column_name] = block
      end
      
      def select_parser(format)
        case format
        when :csv
          # klass = const_define@?(FasterCsvParser) ? FasterCsvParser : CsvParser
          CsvParser.new
        when :xls
          ExcelParser.new
        when :fixed
          FixedWidthParser.new
        else
          raise ArgumentError.new("Could not find parser for unknown format: #{format}")
        end
      end

      # The format will be guessed from the filename extension (.csv or .xls), you can also explicitly set the format using the :format option
      # Options are passed to the parser
      def load(filename, options = {})
        if options[:format] || (ext = File.extname(filename)).empty?
          format = options[:format]
        else
          format = ext[1..-1].downcase.to_sym
        end
        parser = select_parser(format)
        process(parser.load(filename, options))
      end
      
      # Options are passed to the parser
      def parse(data, options = {})
        format = options[:format] || :csv
        parser = select_parser(format)
        process(parser.parse(data, options))
      end
      
      # TODO
      # def inspect
      # end
      
      protected
      
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
        if @name_hints && (n = @name_hints[s])
          n
        elsif (s = s.gsub(/[^a-z_0-9]+/i, '_').gsub(/^(\d)/, '_\1')).empty?
          raise ColumnDefinitionError.new("Column name may not be blank")
        else
          s.to_sym
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