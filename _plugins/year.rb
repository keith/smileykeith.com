module Jekyll
  module YearFilter
    def year(date)
      time(date).strftime("%Y")
    end
  end
end

Liquid::Template.register_filter(Jekyll::YearFilter)

