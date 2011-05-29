helpers do
  def will_paginate(collection)
    total_pages, current_page = collection.total_pages, collection.current_page
    prev = nil
    gap_marker = '&hellip;'
    inner_window, outer_window = 4, 1
    window_from = current_page - inner_window
    window_to = current_page + inner_window
    @links = []

    return nil unless total_pages > 1

    if window_to > total_pages
      window_from -= window_to - total_pages
      window_to = total_pages
    end
    if window_from < 1
      window_to += 1 - window_from
      window_from = 1
      window_to = total_pages if window_to > total_pages
    end

    visible   = (1..total_pages).to_a
    left_gap  = (2 + outer_window)...window_from
    right_gap = (window_to + 1)...(total_pages - outer_window)
    visible  -= left_gap.to_a  if left_gap.last - left_gap.first > 1
    visible  -= right_gap.to_a if right_gap.last - right_gap.first > 1

    visible.inject [] do |links, n|
      links << {:text => gap_marker, :link => false, :active => false} if prev and n > prev + 1
      links << {:text => n, :link => n != current_page ? true : false, :active => n != current_page ? false : true}
      prev = n
      @links = links
    end

    haml :"helpers/pagination"
  end

  def ago(time)
    diff = Time.now - Time.parse(time.to_s)
    ranges = { :second => 1..59, :minute => 60..3559, :hour => 3600..86399,
      :day => 86400..2592000, :month => 2592000..31104000, :year => 31104000..999999999 }

    return 'just now' if diff < 5

    ranges.collect do |n,r|
      "#{(diff/r.first).ceil} #{n}#{'s' if (diff/r.first).ceil > 1} ago" if r.include? diff
    end.join
  end

  def you(name)
    if name == @cur_user.name
      "you"
    else
      name
    end
  end

  def goto(parent_id, post_id, per_page)
    count = Activity.first(:id => parent_id).children(:type => :reply, :id.lt => post_id).count
    page  = (count / per_page).floor + 1
    if page == 1
      "/thread/" + parent_id.to_s + "#p" + post_id.to_s
    else
      "/thread/" + parent_id.to_s + "/page/" + page.to_s + "#p" + post_id.to_s
    end
  end

  def make_bytes(bytes, max_digits=3)
    k = 2.0**10
    m = 2.0**20
    g = 2.0**30
    t = 2.0**40
    value, suffix, precision = case bytes
      when 0...k
        [ bytes, 'b', 0 ]
      else
        value, suffix = case bytes
          when k...m
            [ bytes / k, 'kB' ]
          when m...g
            [ bytes / m, 'MB' ]
          when g...t
            [ bytes / g, 'GB' ]
          else
            [ bytes / t, 'TB' ]
        end
        used_digits = case value
          when   0...10
            1
          when  10...100
            2
          when 100...1000
            3
        end
        leftover_digits = max_digits - used_digits
        [ value, suffix, leftover_digits > 0 ? leftover_digits : 0 ]
    end
    "%.#{precision}f#{suffix}" % value
  end

  def megapixels(string)
    dimensions = string.split("x")
    width  = dimensions[0]
    height = dimensions[1]
    mp     = (width.to_f * height.to_f) / 1000000.0
    mp     = (mp * 10).round / 10.0
    mp
  end

  def ellipse_url(url, length = 30)
    url = url.gsub(/http:\/\/(www\.)?/, "")
    if url.length >= length
      url1 = url[0..(length / 2)]
      url2 = url[-(length / 2)..-1]
      url1 + "&hellip;" + url2
    else
      url
    end
  end

  def feed_title(o)
    case o.type
    when :post, :video, :link
      o.title
    when :image
      "#" + o.id.to_s
    end
  end

  def feed_content(o)
    case o.type
    when :post
      markdown(o.content)
    when :image
      markdown("![](#{o.image.url(:medium)})\n\n#{o.content}")
    when :link
      markdown("[#{o.title}](#{o.meta["url"]})\n\n#{o.content}")
    when :video
      markdown("[#{o.title}](#{o.meta["video_url"]})\n\n#{o.content}").meta["video_html"]
    end
  end
end
