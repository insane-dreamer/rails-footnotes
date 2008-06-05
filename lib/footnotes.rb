module Footnotes
  class Filter
    @@no_style = false
    # Edit notes
    @@notes = [ :controller, :view, :layout, :stylesheets, :javascripts ]
    # Show notes
    @@notes += [:session, :cookies, :params, :filters, :routes, :queries, :log, :general]

    cattr_accessor :no_style, :notes, :prefix

    def self.filter(controller)
      filter = Footnotes::Filter.new(controller)
      filter.add_footnotes!
      filter.reset!
    end

    def initialize(controller)
      @controller = controller
      @template = controller.instance_variable_get('@template')
      @body = controller.response.body
      @notes = []
      initialize_notes!
    end

    def initialize_notes!
      @@notes.flatten.each do |note|
        @notes << eval("Footnotes::Notes::#{note.to_s.camelize}Note").new(@controller)
      end
    end

    def add_footnotes!
      if performed_render? && first_render?
        if valid_format? && valid_content_type? && !xhr?
          insert_styles unless Footnotes::Filter.no_style
          insert_footnotes
        end
      end
    rescue Exception => e
      # Discard footnotes if there are any problems
      RAILS_DEFAULT_LOGGER.error "Footnotes Exception: #{e}\n#{e.backtrace.join("\n")}"
    end

    def performed_render?
      @controller.instance_variable_get('@performed_render')
    end

    def first_render?
      @template.first_render
    end

    def valid_format?
      [:html,:rhtml,:xhtml,:rxhtml].include?(@template.template_format.to_sym)
    end

    def valid_content_type?
      c = @controller.response.headers['Content-Type']
      (c.nil? || c =~ /html/)
    end

    def xhr?
      @controller.request.xhr?
    end
    
    def reset!
      @notes.map(&:reset!)
    end

    #
    # Insertion methods
    #
    def insert_styles
      insert_text :before, /<\/head>/i, <<-HTML
      <!-- Footnotes Style -->
      <style type="text/css">
        #tm_footnotes_debug {margin: 2em 0 1em 0; text-align: center; color: #444; line-height: 16px;}
        #tm_footnotes_debug a {text-decoration: none; color: #444; line-height: 18px;}
        #tm_footnotes_debug pre {overflow: scroll; margin: 0;}
        #tm_footnotes_debug thead {text-align: center;}
        #tm_footnotes_debug table td {padding: 0 5px;}
        #tm_footnotes_debug tbody {text-align: left;}
        #tm_footnotes_debug legend, #tm_footnotes_debug fieldset {background-color: #FFF;}
        fieldset.tm_footnotes_debug_info {text-align: left; border: 1px dashed #aaa; padding: 0.5em 1em 1em 1em; margin: 1em 2em 1em 2em; color: #444;}
        /* Aditional Stylesheets */
        #{@notes.map(&:stylesheet).compact.join("\n")}
      </style>
      <!-- End Footnotes Style -->
      HTML
    end

    def insert_footnotes
      footnotes_html = <<-HTML
      <!-- Footnotes -->
      <div style="clear:both"></div>
      <div id="tm_footnotes_debug">
        #{links}
        #{fieldsets}
        <script type="text/javascript">
          function untoogle(){
            #{untoogle}
          }
          function toogle(id){
            s = document.getElementById(id).style;
            before = s.display;
            untoogle();
            if(before != 'block'){
              s.display = 'block';
              location.href ='#'+id;
            }
          }
          /* Additional Javascript */
          #{@notes.map(&:javascript).compact.join("\n")}
        </script>
      </div>
      <!-- End Footnotes -->
      HTML
      if @body =~ %r{<div[^>]+id=['"]tm_footnotes['"][^>]*>}
        # Insert inside the "tm_footnotes" div if it exists
        insert_text :after, %r{<div[^>]+id=['"]tm_footnotes['"][^>]*>}, footnotes_html
      else
        # Otherwise, try to insert as the last part of the html body
        insert_text :before, /<\/body>/i, footnotes_html
      end
    end

    def links
      links = Hash.new([])
      order = []
      @notes.each do |note|
        next unless note.valid?
        order << note.row
        links[note.row] += [link_helper(note.to_sym, note.title, note.link)]
      end

      html = ''
      order.uniq!
      order.each do |row|
        html << "#{row.to_s.capitalize}: #{links[row].join(" | \n")}<br />"
      end
      html
    end

    def fieldsets
      content = ''
      @notes.each do |note|
        next unless note.fieldset?
        content << <<-HTML
          <fieldset id="#{note}_debug_info" class="tm_footnotes_debug_info" style="display: none">
            <legend>#{note.legend}</legend>
            <code>#{note.content}</code>
          </fieldset>
        HTML
      end
      content
    end

    def untoogle
      javascript = ''
      @notes.each do |note|
        next unless note.untoogle?
        javascript << untoogle_helper(note)
      end
      javascript
    end

    # Helpers
    #
    def untoogle_helper(name)
      "document.getElementById('#{name}_debug_info').style.display = 'none'\n"
    end

    def link_helper(sym, content, link)
      if link
        href = link
        onclick = ''
      else
        href = '#'
        onclick = "toogle('#{sym}_debug_info');return false;"
      end

      "<a href=\"#{href}\" onclick=\"#{onclick}\">#{content}</a>"
    end

    # Inserts text in to the body of the document
    # +pattern+ is a Regular expression which, when matched, will cause +new_text+
    # to be inserted before or after the match.  If no match is found, +new_text+ is appended
    # to the body instead. +position+ may be either :before or :after
    #
    def insert_text(position, pattern, new_text)
      index = case pattern
        when Regexp
          if match = @body.match(pattern)
            match.offset(0)[position == :before ? 0 : 1]
          else
            @body.size
          end
        else
          pattern
        end
      @body.insert index, new_text
    end
  end
end