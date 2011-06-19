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