require 'twilio-ruby'

def make_call(count)
  $logger.info "making calling for ... #{count} times"
  # Find your Account SID and Auth Token at twilio.com/console
  # and set the environment variables. See http://twil.io/secure
  account_sid = ENV["ACCOUNT_SID"]
  auth_token = ENV["AUTH_TOKEN"]
  @client = Twilio::REST::Client.new(account_sid, auth_token)

  numbers = ENV["TO"].split(",")
  numbers.each do |number|
    call = @client.calls.create(
                          url: 'http://demo.twilio.com/docs/voice.xml',
                          to: number,
                          from: ENV["FROM"]
                        )
    $logger.info "#{number} => #{call.sid}"
  end
end
