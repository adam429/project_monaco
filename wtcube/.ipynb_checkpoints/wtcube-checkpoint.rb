require "active_support/all"
require 'action_view'
require 'awesome_print'
require 'erb'
require 'chartkick'
require 'httparty'
require 'nokogiri'


module WTCube

  # ------ Math ------   
    def diff(arr)
        tmp1 = arr.clone.map do |x| x[1] end
        tmp1.pop
        tmp2 = arr.clone.map do |x| x[1] end
        tmp2.shift

        diff_rate = tmp1.zip(tmp2).map do |x| if x[0]==nil then nil else (x[1]-x[0])/x[0] end end
        diff_rate = diff_rate.map.with_index do |x,i| [i,x] end

        return diff_rate
    end
    
  # --------- Network --------
  def http_get(url)  ## with file cache
    filename = url.match(/\/([^\/]+)$/)[1]

    begin
      return File.read("./wtcube/assets/#{filename}")
    rescue Errno::ENOENT => e
      response = HTTParty.get(url)
      return response.body
    end
  end

  # ----------- Config -------------
  def include_js(cache=false)
    js = [
            "http://unpkg.com/vue/dist/vue.js",
            "http://unpkg.com/jquery@3.6.0/dist/jquery.js",
            "http://www.gstatic.com/charts/loader.js",
            "http://unpkg.com/chart.js@2.9.3/dist/Chart.bundle.js",
            "http://unpkg.com/chartkick@2.3.0/chartkick.js",
            "http://unpkg.com/vue-chartkick@0.5.1/dist/vue-chartkick.js",
            "http://unpkg.com/element-ui/lib/index.js",
         ]

     return js.map do |x| "<script> #{http_get(x)} </script>" end.join() if cache
     return js.map do |x| "<script src='#{x}'></script>" end.join() if not cache
  end

    def include_css
    css= [
            "https://unpkg.com/element-ui/lib/theme-chalk/index.css"
         ]
    css_html = css.map do |x| "<link rel='stylesheet' href='#{x}'>" end.join()
    return css_html
  end


  # ----------- Helper -------------

  def humanize(secs)
    ret =
    [[60, :seconds], [60, :minutes], [24, :hours], [Float::INFINITY, :days]].map{ |count, name|
      if secs > 0
        secs, n = secs.divmod(count)

        "#{n.to_i} #{name}" unless n.to_i==0
      end
    }.compact.reverse.join(' ')
    ret = "0 second" if ret==""
    return ret
  end

  def ratio(a,b)
      return 0 if b==0
      return (a.to_f / b).round(2)
  end


  # --------- Display --------

  def puts_table(table,option={maxrows:30})
    table = table.map do |x|
      x.map do |y|
        ret = y.to_s
        if /\.(jpg|png|jpeg)$/.match(y.to_s) then
          ret = "<img src='#{y.to_s}' width='150'/>"
        end

        ret
      end
    end
    if option[:file]
      File.open(option[:file],"w") do |file|
        file.write(IRuby.table(table,maxrows:999999,maxcols:999999).object)
      end
    else
      IRuby.display IRuby.table(table,maxrows:option[:maxrows],maxcols:15)
      nil
    end
  end

  def puts_header(text, option={level:1})
    IRuby.display IRuby.html "<h#{option[:level]}>#{text}</h#{option[:level]}>"
  end

  def puts_image(image)
    if image.class == String then
      IRuby.display IRuby.html "<img src='#{image}' width='500'/>"
    end

    if image.class == Array then
      IRuby.display IRuby.html (image.map do |x| "<img src='#{x}' width='500'/>" end.join("\n"))
    end
    nil
  end

  def _parse_obj(obj)
    html = ""
    if obj.class==ActiveSupport::SafeBuffer
       html = obj.to_s
    elsif obj.class==String
      if /\.(jpg|png|jpeg|svg)$/.match(obj) then
        html = "<img src='#{obj}' width='500'/>"
      elsif  /^http/.match(obj) then
        html = "<iframe src='#{obj}' width='800' height='600'/>"
      elsif /<div|<a href|<img|<script/.match(obj) then
        html = obj
      else
        html = obj
      end
    else
       html = obj.ai(html:true)
    end
    return html
  end

  def puts_raw(obj)
    IRuby.display obj.to_s
  end

  def puts(obj)
    IRuby.display IRuby.html _parse_obj(obj)
    nil
  end

  def puts_to_file(obj,filename)
    f = open(filename,"w")
    f.write("<!DOCTYPE html>")
    f.write("<html>")
    f.write("<head>")
    f.write("<meta charset='utf-8'/> ")
    f.write(include_js)
    f.write(include_css)
    f.write("</head>")
    f.write("<body>")
    f.write(_parse_obj(obj))
    f.write("</body>")
    f.write("</html>")
    f.close
  end

  # --------- Template --------

  def render(template,params={})
    template = File.read("template/"+template.to_s+".erb") unless template.match(/\n/)
    erb = ERB.new(template)
    html = erb.result_with_hash(params)

    # move all script to end part of html (for vue)
    doc = Nokogiri::HTML::DocumentFragment.parse(html)
    js = doc.css("script")
    js.remove
    return doc.to_html + js.reverse.to_html
  end

  # ---- Color Pattern ----

  def color()
    [
      "#60acfc",
      "#32d3eb",
      "#5bc49f",
      "#feb64d",
      "#ff7c7c",
      "#9287e7"
    ]
  end

end


# Load WTCube into main space
include WTCube

# Load Chartkick
include Chartkick::Helper
# Load ActionView Helper
include ActionView::Helpers::NumberHelper