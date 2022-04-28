# echo "1234567890" | socat - UNIX-CONNECT:/tmp/selenium.sock
require "selenium-webdriver"
require "logger"
require "fileutils"
require "socket"
require "./twilio.rb"
require 'open-uri'
require "./capatcha"
require 'mini_magick'
## install selenium-devtools
## make changes to the code.
SOCKET = "/tmp/selenium.sock"

FileUtils.rm_rf(SOCKET)

## remove directory
["screenshot", "capatcha", "html", "logs"].each do |dir|
  newDir = File.join(Dir.pwd, dir)
  FileUtils.rm_rf(newDir)
end

## create directory
["screenshot", "capatcha", "html", "logs"].each do |dir|
  newDir = File.join(Dir.pwd, dir)
  FileUtils.mkdir_p(newDir) 
end

## create log file
logFile = STDOUT #File.join(Dir.pwd, 'logs/', 'selenium.log')
$logger = Logger.new(logFile)
$screenshot = 0 # $screenshot
$source = 0 # $source
$capatcha = 0 # $capatcha

Signal::trap("TERM") do 
  $runner = false
  $noRun = false
  $onLoop = true
end

def save_source(driver) 
  $source += 1
  File.open(File.join(Dir.pwd, "html", "#{$source}.html"), "w") do |file|
    file.puts driver.page_source
  end

  $logger.info "scp #{ENV['SSH_HOST']}:/home/virendranegi/selenium/html/#{$source}.html ."
end

## ok
def screenshot(driver)
  $screenshot += 1
  driver.save_screenshot("#{Dir.pwd}/screenshot/screenshot-#{$screenshot}.png")
  $logger.info "scp #{ENV['SSH_HOST']}:/home/virendranegi/selenium/screenshot/screenshot-#{$screenshot}.png ."
end

def crop_capatcha(element)
  
  $capatcha += 1
  $logger.info "Cropping captcha .." 
  gets()
  ordinate = element.location
  size = element.size()
  $logger.info "Taking last screenshot screenshot-#{$screenshot}.png"

  image = MiniMagick::Image.open("#{Dir.pwd}/screenshot/screenshot-#{$screenshot}.png")
  $logger.info "#{size.width}x#{size.height}+#{ordinate.x}+#{ordinate.y}"
  $logger.info "#{size.width}x#{size.height}+1650.984375+770.5625"
  image.crop "220x75+1567+757"
  $logger.info "#{size.width}x#{size.height}+1650.984375+770.5625"
  image.write("#{Dir.pwd}/capatcha/#{$capatcha}.png")
  return "#{Dir.pwd}/capatcha/#{$capatcha}.png"
end

def wait()
  $logger.info "entering unix mode"
  server = UNIXServer.new(SOCKET)
  socket = server.accept
  code = socket.readline
  captcha.chomp!
  socket.close()
  FileUtils.rm_rf(SOCKET)
  $logger.info "exiting unix mode"
  return code
end

$logger.info Process.pid

$logger.info "creating driver ..."
def start()
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  driver = Selenium::WebDriver.for :chrome, options: options
  driver.manage.window.resize_to(1024, 900)
  driver.intercept do |request, &continue|
    continue.call(request) do |response|
      $status_code = response.code if $status_url == request.url
    end
  end
  return driver
end

def navigate(driver, url)
  $status_code = 999
  $status_url = url
  driver.navigate.to url
end 

def status_code; $status_code ; end

def login(driver)
  begin
    navigate(driver, "https://heliservices.uk.gov.in/User/userlogin.aspx")
    $logger.info "received #{status_code}" unless status_code == 200
    return false unless status_code == 200
    return false unless driver.current_url == "https://heliservices.uk.gov.in/User/userlogin.aspx"
    $logger.info "navigated to home page"
    user = ENV["USER"]
    password = ENV["PASSWORD"]
    $logger.info "entering login ..."
    driver.find_element(id: "ContentPlaceHolderBody_txtname").send_keys(user)
    driver.find_element(id: "ContentPlaceHolderBody_txtpwd").send_keys(password)
    sleep 10

    capatcha_element = driver.find_element(css: 'img.img-responsive[alt="Visual verification"]')
    screenshot(driver)
    captcha_image = crop_capatcha(capatcha_element)
    ok, text = find_capatcha(captcha_image)
    return false unless ok 
    
 
    $logger.info "obtained captcha is #{text}... "
    gets()
    return false if text.length != 6
    $logger.info "Correct captcha."

    driver.find_element(id: "ContentPlaceHolderBody_tbCaptha").clear()
    driver.find_element(id: "ContentPlaceHolderBody_tbCaptha").send_keys(text)
    driver.find_element(id: "ContentPlaceHolderBody_btn_login").click()
    $logger.info "login page filled and clicked entering loop"
    return true
  rescue Exception => exception
    $logger.info ".. current path #{driver.current_url}"
    $logger.error "we got exception while login #{exception.message} #{exception.backtrace}"
    return false  
  end
end


def loopCall(driver)
  $onLoop = false
  # while(!$onLoop) do
  #   $onLoop = login(driver)
  # end

  login(driver)
  exit

  $runner = true
  exceptionCount = 0
  $refresh = false
  $refreshAttempt = 0
  while($runner) do
    begin
      sleepTime = 200
      navigate(driver, "https://heliservices.uk.gov.in/User/CheckAvailability.aspx") if $refresh
    
      if status_code == 200
        $logger.info "all good"
        $refresh = false
        $refreshAttempt = 0
      else 
        if ($refreshAttempt > 5) 
          $logger.info "refreshAttemp exceeded"
          $logger.info "making precautionary calls ..."
          make_call(1)
          sleep 60
          return 
        else
          $refreshAttempt += 1
          next 
        end
      end  

      return unless driver.current_url == "https://heliservices.uk.gov.in/User/CheckAvailability.aspx" 
      ## check login
      $logger.info "visting check availability.."
      
      driver.find_element(css: 'div.menu-1 > ul li a').click()
      sleep 5
      
      $logger.info "..."
      driver.find_element(id: 'ContentPlaceHolderBody_txtDepartDate').click()

      $logger.info "taking screenshot ..."
      screenshot(driver)
      ## check whether the calendar is may.
      if driver.find_element(id: 'ContentPlaceHolderBody_CEOpeningDate_title').text() == "May, 2022"
        $logger.info "checking calendar ..."
        invalidDays = driver.find_elements(xpath: "//div[@id='ContentPlaceHolderBody_CEOpeningDate_body']//table//tbody//td[@class='ajax__calendar_invalid']//div").select { |t| t.attribute('title') == 'Saturday, May 21, 2022' }
        if (invalidDays.length == 0)
          $logger.error "we found 21st to a valid day now, make call"
          3.times { |i| make_call(i); sleep 60 } 
          sleepTime = 20
        else
          $logger.info "no change .."
        end
      else
        $logger.error "some problem -> calendar month does not match"
        screenshot(driver)
        3.times { |i| make_call(i); sleep 60 }
        sleepTime = 20
      end
      exceptionCount = 0  
      $logger.info "Sleeping for #{sleepTime} seconds"
      sleep sleepTime
    rescue Exception => e
      $refresh = true if e.message =~ /no such element/ 
      $logger.error "Got error  ...#{e.message} #{e.backtrace}"
      $logger.info "taking screenshot ..."
      screenshot(driver)
      $logger.info "saving html source ..."
      save_source(driver)
    end
  end
end

def execute()
  $noRun = true
  while($noRun)
    driver = start()
    loopCall(driver)
    driver.quit()
  end  
end

execute()

$logger.info ".. deleting socket"
FileUtils.rm_rf(SOCKET)
