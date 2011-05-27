helpers do
    def paper_hash(file_hash)
    hash = Hash.new
    hash['tempfile'] = file_hash[:tempfile]
    hash['filename'] = file_hash[:filename]
    hash['content_type'] = file_hash[:type]
    hash['size'] = file_hash[:tempfile].size
    hash
    end
end