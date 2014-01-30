Foo.


# scraperwiki / custard #

A platform for tools that do stuff with data.

Together with cobalt, custard powers the [new ScraperWiki platform](https://scraperwiki.com).

AGPL Licenced (see LICENCE file).

## Initial setup (mongo, redis, nvm)

On Debian or Ubuntu:

    sudo apt-get install -y mongodb
    sudo apt-get install -y redis-server

You'll need a bunch of node stuff:

    sudo apt-get install -y npm
    curl https://raw.github.com/creationix/nvm/master/install.sh | sh

And fix the node version by adding these lines to your `.profile`:

    . ~/.nvm/nvm.sh
    nvm use 0.10

start a new bash terminal (in order to get nvm which is a shell function)

   nvm install 0.10

On Mac OSX:

    brew install mongodb
    brew install redis

Clone this repo (inside `~/sw` preferable) and from within the `custard` directory:

Then on all platforms:

    mkdir mongo
    npm install pow-mongodb-fixtures -g
    mongod --dbpath=mongo # might be running already
    # redis-server # probably don't need this, as it's already running

Alongside custard, you will need to git clone swops-secret

    git clone blah blah blah

## Mac foibles

The maxfiles ulimit on Mac OSX is ludicrously low. This can cause problems (eg: `username-duplicate` errors from the users POST endpoint) when `mongod` attempts to create the number of connections specified in `server/index.coffee`.

To increase your maxfiles limit on Mac OSX, create a file at `/etc/launchd.conf` and paste this into it:

    limit maxproc 512 1024
    limit maxfiles 1024 2048

You should then restart mongod if it's already running.

OSX users might also want to install the mongodb and redis System Preference Panes, which make it dead easy to turn both servers on and off whenever required:

- https://github.com/remysaissy/mongodb-macosx-prefspane
- https://github.com/dquimper/Redis.prefPane

## Automatically getting the correct environment with direnv

[direnv](http://direnv.net) can be used to automatically "activate" the environment
when you enter the directory. Briefly:

    # (install go and set up your GOPATH and PATH sensibly)
    go get github.com/zimbatm/direnv
    go install github.com/zimbatm/direnv

    # append direnv setup to your bash profile
    echo 'eval "$(direnv hook $0)"' >> ${HOME}/.bashrc

    # Then cd to the custard directory and enable the .envrc with direnv:
    :~$ cd sw/custard/
    .envrc is not allowed

    :~/sw/custard$ direnv allow
    direnv: loading ~/sw/.envrc
    connect-assets not found, please run npm install
    direnv export: +NODE_PATH +PYTHONPATH +VIRTUAL_ENV ~PATH

## The first time and then every now and then (npm updates)

    # cd into the custard directory
    . activate
    npm install

## Every time you need to develop custard

    # Start a web server (best done in a new window)
    . activate # don't need to do this again if you've already done it in this terminal
    cake dev

The `cake dev` above starts custard the web server. It's listening on a local port (usually 3001),
so you should be able to visit `localhost:3001` in a web browser.

## Tests

We love them.

First, download and unzip Selenium Server and Chromedriver, and put them in your custard directory or the next level up:

- https://code.google.com/p/selenium/downloads/list
- https://code.google.com/p/chromedriver/downloads/list

If you're wondering about versions, right now we're having luck with:

- [Selenium Server Standalone 2.35.0](https://selenium.googlecode.com/files/selenium-server-standalone-2.35.0.jar)
- [Chromedriver Mac32 2.2](https://chromedriver.googlecode.com/files/chromedriver_mac32_2.2.zip)
- [Chromedriver Linux64 2.2](https://chromedriver.googlecode.com/files/chromedriver_linux64_2.2.zip)

Then start the Selenium server using `cake se`:

    . activate && cake se

(this is a shortcut for running `java -jar selenium-server-standalone-2.*.0.jar -Dwebdriver.chrome.driver=chromedriver`)

To run the tests:

    . activate && cake dev       # runs a local webserver, as above
    mocha

Or one of these:

    mocha test/unit
    mocha test/integration

## Optional: running Selenium on a Windows machine

### On the Windows machine

- Make sure Java is installed
- Download the selenium-server jar file (from http://www.seleniumhq.org/download/)
- Download, unpack and add to your path the IE driver (avaiable on the same download page)
- Run Selenium Server using the command `java -jar selenium-server-standalone-2.*.0.jar`
- Run ipconfig in a cmd window to find out the IP address (e.g. 192.168.1.100)

### On your local machine

- `export SELENIUM_HOST=192.168.1.100`
- `export SELENIUM_PORT=4444`
- `export BROWSER=iexplorer`
- `export CU_TEST_SERVER=<local ip address>`
- run mocha as above and it will use the Windows machine to run the tests

## Optional: disabling startup services

You may wish to disable redis-server and mongodb services from autostarting on boot when not developing custard.

(Tested on Ubuntu 12.04)

Disable mongo service:

    echo "manual" | sudo tee /etc/init/mongodb.override

Enable mongo service:

    sudo rm /etc/init/mongodb.override

Disable redis-server service:

    sudo update-rc.d redis-server disable

Enable redis-server service:

    sudo update-rc.d redis-server enable
