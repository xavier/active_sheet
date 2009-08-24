
module ActiveSheet
    
  class AbstractColumn
    
    attr_accessor :name
    
    def initialize(name, options = {})
      @name    = name
      @options = options
      process_options
    end
    
    def process_options
    end
    
    # Returns the actual value for the cell -- Implemented in concret column classes
    def value(s)
      raise NotImplementedError
    end
    
    def consider_blank?(s)
      s !~ /\S/
    end
    
  end
  
  class StringColumn < AbstractColumn
    
    def consider_blank?(s)
      false
    end
    
    def value(s)
      s
    end
    
  end

  class IntegerColumn < AbstractColumn
    
    def process_options
      @allow_blank = @options[:allow_blank]
    end
    
    def value(s)
      s.to_i
    end
    
  end
  
  class DecimalColumn < AbstractColumn
    
    def value(s)
      BigDecimal(s)
    end
    
  end

  class FloatColumn < AbstractColumn
    
    def value(s)
      s.to_f
    end
    
  end

  class DateColumn < AbstractColumn
    
    def value(s)
      Date.parse(s)
    end
    
  end

  class TimeColumn < AbstractColumn
    
    def value(s)
      Time.parse(s)
    end
    
  end

  class DatetimeColumn < AbstractColumn
    
    def value(s)
      DateTime.parse(s)
    end
    
  end
  
end