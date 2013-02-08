# Test using Selenium WebDriver with wd bindings
# Quick instructions
# Download Selenium WebDriver
#     wget http://selenium.googlecode.com/files/selenium-server-standalone-2.29.0.jar
# Download and unzip ChromeDriver
#     (linux) wget http://chromedriver.googlecode.com/files/chromedriver_linux64_26.0.1383.0.zip
#     (mac) curl -o https://chromedriver.googlecode.com/files/chromedriver_mac_26.0.1383.0.zip
# Start Selenium server
#     java -jar selenium-server-standalone-2.29.0.jar -Dwebdriver.chrome.driver=<path to chromedriver>

wd = require 'wd'
should = require 'should'


BASE_URL = 'http://localhost:3001' # DRY DRY DRY
login_url = "#{BASE_URL}/login"
browser = wd.remote()
wd40 = require('../wd40')(browser)


describe 'Tool RPC', ->
  before (done) ->
    wd40.init done

  before (done) ->
    browser.get login_url, ->
      wd40.fill '#username', 'ehg', ->
        wd40.fill '#password', 'testing', ->
          wd40.click '#login', done

  context "when create a dataset with the test app", ->
    before (done) ->
      browser.get "#{BASE_URL}/tools", =>
        wd40.click '.test-app.tool', =>
          browser.waitForElementByCss 'iframe', 4000, =>
            wd40.trueURL (err, url) =>
              @toolURL = url
              done()
              
    context 'when the redirect internal button is pressed', ->
      before (done) ->
        wd40.switchToBottomFrame ->
          wd40.click '#redirectInternal', (err, btn) ->
            wd40.switchToTopFrame done

      it 'redirects the host to the specified URL', (done) ->
        wd40.trueURL (err, url) ->
          url.should.equal "#{BASE_URL}/"
          done()

    context 'when the redirect external button is pressed', ->
      before (done) ->
        browser.get @toolURL, ->
          wd40.switchToBottomFrame ->
            wd40.click '#redirectExternal', (err, btn) ->
              wd40.switchToTopFrame done

      it 'redirects the host to the specified URL', (done) ->
        wd40.trueURL (err, url) ->
          url.should.equal 'http://www.google.com/robots.txt'
          done()

    context 'when the showURL button is pressed', ->
      before (done) ->
        browser.get @toolURL, ->
          wd40.switchToBottomFrame ->
            wd40.click '#showURL', (err, btn) ->
              wd40.switchToTopFrame done

      before (done) ->
        wd40.switchToBottomFrame done

      it 'shows the scraperwiki.com URL in an element', (done) ->
        wd40.getText '#textURL', (err, text) =>
          text.should.equal @toolURL
          done()

    context 'when the rename button is pressed', ->
      before (done) ->
        browser.get @toolURL, ->
          wd40.switchToBottomFrame ->
            wd40.click '#rename', (err, btn) ->
              wd40.switchToTopFrame done

      it 'renames the dataset', (done) ->
        wd40.waitForText 'Test Dataset (renamed)', done

  after (done) ->
    browser.quit ->
      done()
