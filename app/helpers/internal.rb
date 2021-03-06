helpers do
  def markdownit(text)
    html = Redcarpet.new(text, :gh_blockcode, :fenced_code, :safelink, :filter_html, :strikethrough).to_html
    html.gsub(/(^|[\n ])@([\w]{1,30})/im, "\\1@<a href=\"/user/\\2\">\\2</a>")
  end

  def paper_hash(file_hash)
    hash = Hash.new
    hash['tempfile'] = file_hash[:tempfile]
    hash['filename'] = file_hash[:filename]
    hash['content_type'] = file_hash[:type]
    hash['size'] = file_hash[:tempfile].size
    hash
  end

  def download_image(image_url)
    io = open(URI.parse(image_url))
    def io.original_filename; base_uri.path.split('/').last; end
    io.original_filename.blank? ? nil : io
  end
end

module Zeon
  class OStatus
    HEADER = { "Content-Type" => "application/x-www-form-urlencoded" }

    # Fetch Webfinger
    def finger(acct)
      uri     = URI.parse(acct).host || acct.split('@')[1]
      xrd_get = RestClient.get("http://#{uri}/.well-known/host-meta")
      xrd     = Nokogiri::XML::Document.parse xrd_get

      finger_uri  = xrd.at("Link[rel=lrdd]")["template"]
      finger_get  = RestClient.get(finger_uri.gsub("{uri}", acct))
      finger      = Nokogiri::XML::Document.parse finger_get

      finger
    end
    # Publish feed to hub
    def publish(hub, feed)
      RestClient.post(hub, :headers => HEADER, 'hub.mode' => 'publish', 'hub.url' => feed)
    end
    # Subscribe to a feed through a hub
    def subscribe(feed, callback)
      RestClient.post(hub, :headers => HEADER, 'hub.mode' => 'subscribe', 'hub.topic' => feed, 'hub.callback' => callback, 'hub.verify' => 'async')
    end
    # Unsubscribe from a feed through a hub
    def unsubscribe(feed, callback)
      RestClient.post(hub, :headers => HEADER, 'hub.mode' => 'unsubscribe', 'hub.topic' => feed, 'hub.callback' => callback, 'hub.verify' => 'async')
    end
  end
end
