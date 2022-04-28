

require 'base64'
require 'json'
require 'net/https'

def find_capatcha(image)
  # Step 1 - Set path to the image file, API key, and API URL.

  #API_KEY = ENV['API_KEY']
  api_url = "https://vision.googleapis.com/v1/images:annotate?key=#{api_key}"
  $logger.info "... creating base64 image"
  # Step 2 - Convert the image to base64 format.
  base64_image = Base64.strict_encode64(File.new(image, 'rb').read)
  # Step 3 - Set request JSON body.
  body = {
    requests: [{
      image: {
        content: base64_image
      },
      features: [
        {
          type: 'TEXT_DETECTION', # Details are below.
          maxResults: 1 # The number of results you would like to get
        }
      ]
    }]
  }
  $logger.info "... sending base64 image"
  
  uri = URI.parse(api_url)
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri)
  request["Content-Type"] = "application/json"
  httpResponse = https.request(request, body.to_json)
  response = JSON.parse(httpResponse.body)
  return false, "" unless response.has_key?('responses')
  return false, "" if response['responses'].empty?
  responseObj = response['responses']
  return false, ""  unless responseObj[0].has_key?('fullTextAnnotation')
  fullText = responseObj[0]["fullTextAnnotation"]
  return false, ""  unless fullText.has_key?('text')
  text = fullText["text"]
  text.chomp!
  $logger.info "obtained capatcha is #{text}"
  return true, text
end
