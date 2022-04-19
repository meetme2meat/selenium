# echo "1234567890" | socat - UNIX-CONNECT:/tmp/selenium.sock
require "selenium-webdriver"
require "logger"
require "fileutils"
require "socket"
require "./twilio.rb"

SOCKET = "/tmp/selenium.sock"

["screenshot", "logs"].each do |dir|
  newDir = File.join(Dir.pwd, dir)
  FileUtils.rm_rf(newDir)
end

["screenshot", "logs"].each do |dir|
  newDir = File.join(Dir.pwd, dir)
  FileUtils.mkdir_p(newDir) 
end

logFile = File.join(Dir.pwd, 'logs/', 'selenium.log')
$logger = Logger.new(logFile)
$screenshot = 0

Signal::trap("TERM") do 
  $runner = false
end

def screenshot(driver)
  $screenshot += 1
  driver.save_screenshot("#{Dir.pwd}/screenshot/screenshot-#{$screenshot}.png")
end



$logger.info Process.pid

$logger.info "creating driver ..."
options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless')
driver = Selenium::WebDriver.for :chrome, options: options
#driver = Selenium::WebDriver.for :chrome
driver.manage.window.resize_to(1024, 900)
driver.navigate.to "https://heliservices.uk.gov.in/User/userlogin.aspx"
$logger.info "navigated to home page"

screenshot(driver)

user = ENV["USER"]
password = ENV["PASSWORD"]
$logger.info "entering login ..."
driver.find_element(id: "ContentPlaceHolderBody_txtname").send_keys(user)
driver.find_element(id: "ContentPlaceHolderBody_txtpwd").send_keys(password)
puts "enter captcha... "
server = UNIXServer.new(SOCKET)
socket = server.accept
captcha = socket.readline
captcha.chomp!
socket.close()
driver.find_element(id: "ContentPlaceHolderBody_tbCaptha").clear()
driver.find_element(id: "ContentPlaceHolderBody_tbCaptha").send_keys(captcha)
driver.find_element(id: "ContentPlaceHolderBody_btn_login").click()

$logger.info "login page filled and clicked entering loop"
## check login 
$runner = true
#driver.manage.window.resize_to(1024, 900)
while($runner) do
  sleepTime = 200
  screenshot(driver)
  ## check login
  $logger.info "visting check availability.."
  driver.navigate.to "https://heliservices.uk.gov.in/User/CheckAvailability.aspx"
  
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
    end
  else
    $logger.error "some problem -> calendar month does not match"
    screenshot(driver)
    3.times { |i| make_call(i) sleep 60 }
    sleepTime = 20
  end  
  sleep sleepTime
end
driver.quit()
$logger.info ".. deleting socket"
FileUtils.rm(SOCKET)