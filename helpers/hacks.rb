class OEmbed
  def self.valid?(url, *attribs)
    unless (vschemes = @schemes.select { |a| url =~ a[0] }).empty?
      regex, provider = vschemes.first
      data = get_url_for_provider(url, provider, *attribs)
      if data.keys.empty?
        false
      else
        response = OEmbed::Response.new(provider, url, data)
        response
      end
    else
      false
    end
  end
end