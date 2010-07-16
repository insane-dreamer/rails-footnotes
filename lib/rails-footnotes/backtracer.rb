module Footnotes
  module Backtracer
    def self.add_links_to_backtrace(line)
      unless ::Footnotes::Filter.prefix.blank? 
        expanded = line.gsub('#{Rails.root.to_s}', Rails.root.to_s)
        if match = expanded.match(/^(.+):(\d+):in/) || match = expanded.match(/^(.+):(\d+)\s*$/)
          file = File.expand_path(match[1])
          line_number = match[2]
          html = %[<a href="#{Footnotes::Filter.prefix(file, line_number, 1)}">#{line}</a>]
        else
          line
        end
      end
    end
  end
end
