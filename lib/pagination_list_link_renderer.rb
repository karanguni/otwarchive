# encoding: UTF-8
# Almost entirely taken from http://thewebfellas.com/blog/2010/8/22/revisited-roll-your-own-pagination-links-with-will_paginate-and-rails-3
#
# <h4 class="landmark heading">Pages Navigation</h4>
# <ol class="navigation pagination actions" title="pagination" role="navigation">
# <li title="previous">&#8592;</li>
# <li><a href="">1</a></li>
# <li><span class="current" title="current">2</span><li>
# </ol>

module WillPaginate
  module ActionView
    def will_paginate(collection = nil, options = {})
      options, collection = collection, nil if collection.is_a? Hash
      collection ||= infer_collection_from_controller

      options = options.symbolize_keys
      options[:renderer] ||= PaginationListLinkRenderer

      super(collection, options).try(:html_safe)
    end


  end
end

    class PaginationListLinkRenderer < WillPaginate::ActionView::LinkRenderer

      protected

        def gap
          tag(:li, "…", :class => "gap")
        end

        def page_number(page)
          unless page == current_page
            tag(:li, link(page, page, :rel => rel_value(page)))
          else
            tag(:li, tag(:span, page, :class => "current"))
          end
        end

        def previous_page
          num = @collection.current_page > 1 && @collection.current_page - 1
          previous_or_next_page(num, @options[:previous_label], 'previous')
        end
        
        def next_page
          num = @collection.current_page < @collection.total_pages && @collection.current_page + 1
          previous_or_next_page(num, @options[:next_label], 'next')
        end

        def previous_or_next_page(page, text, classname)
          if page
            tag(:li, link(text, page), :class => classname, :title => classname)
          else
            tag(:li, text, :class => classname + ' disabled', :title => classname)
          end
        end

        def html_container(html)
          tag(:h4, "Pages Navigation", :class => "landmark heading") + 
            tag(:ol, html, container_attributes.merge(:class => "navigation pagination actions", :role => "navigation", :title => "pagination"))
        end

    end
