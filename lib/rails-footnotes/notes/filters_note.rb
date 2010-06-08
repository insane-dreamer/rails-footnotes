require "#{File.dirname(__FILE__)}/abstract_note"

module Footnotes
  module Notes
    class FiltersNote < AbstractNote
      def initialize(controller)
        @controller = controller
        @parsed_filters = parse_filters
      end

      def legend
        "Filter chain for #{@controller.class.to_s}"
      end

      def content
        mount_table(@parsed_filters.unshift([:name, :type, :actions]), :summary => "Debug information for #{title}")
      end

      protected
        # Get controller filter chain
        #
        def parse_filters
          return @controller.class._process_action_callbacks.collect do |filter|
            #[parse_method(filter.method), filter.type.inspect, controller_filtered_actions(filter).inspect]
            ["", filter.kind.inspect, controller_filtered_actions(filter).inspect]
          end
        end

        # This receives a filter, creates a mock controller and check in which
        # actions the filter is performed
        #
        def controller_filtered_actions(filter)
          mock_controller = Footnotes::Extensions::MockController.new

          return @controller.class.action_methods.select { |action|
            mock_controller.action_name = action

            #remove conditions (this would call a Proc on the mock_controller)
            filter.options.merge!(:if => nil, :unless => nil) 

            (filter.options[:only].nil? && filter.options[:unless].nil?) || 
              (Array(filter.options[:only]).include?(action)) ||
              (!Array(filter.options[:except]).include?(action))
          }.map(&:to_sym)
        end
        
        def parse_method(method = '')
          escape(method.inspect.gsub(RAILS_ROOT, ''))
        end
    end
  end

  module Extensions
    class MockController < Struct.new(:action_name); end
  end
end
