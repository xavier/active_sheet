
module ActiveSheet
  
  class Error < StandardError ; end
  class MissingColumnDefinition < Error ; end
  class ColumnDefinitionError < Error ; end
    
   class Collection < Array
      
      # If you have ActiveSupport loaded, you can use Rails index_by
      # def build_index(symbol = nil, &block)
      #   if block_given?
      #     f = lambda { |row, h| h[(yield row)] = row; h }
      #   else
      #     f = lambda { |row, h| h[row.send(symbol)] = row; h }
      #   end
      #   self.inject({}, f)
      # end
      
  end  
  
end