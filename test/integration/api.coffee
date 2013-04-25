_ = require 'underscore'
request = require 'request'
should = require 'should'
async = require 'async'

settings = require '../settings.json'
serverURL = process.env.CU_TEST_SERVER or settings.serverURL

describe 'API', ->
  before ->
    @toolName = "int-test-#{String(Math.random()*Math.pow(2,32))[0..6]}"
  context "When I'm not logged in", ->
    describe 'Sign up', ->
      context 'POST /api/<username>', ->
        before (done) ->
          request.post
            uri: "#{serverURL}/api/user/"
            form:
              shortName: 'tabbytest'
              displayName: 'Tabatha Testerson'
              email: 'tabby@example.org'
              inviteCode: process.env.CU_INVITE_CODE
          , (err, res, body) =>
            @body = body
            done()

        it 'returns ok', ->
          @body.should.include 'tabbytest'

  context "When I have set my password", ->
    before (done) ->
      @token = '339231725782156'
      @user = 'ickletest'
      @password = 'toottoot'
      @fullName = 'Mr Ickle Test'

      # Set password & login
      request.post
        uri: "#{serverURL}/api/token/#{@token}"
        form:
          password: @password
      , done

    describe 'Tools', ->
      context 'POST /api/tools', ->
        context 'when I create a tool (without specifying privacy)', ->
          before (done) ->
            request.post
              uri: "#{serverURL}/api/tools"
              form:
                name: @toolName
                type: 'view'
                gitUrl: 'git://github.com/scraperwiki/spreadsheet-tool.git'
            , (err, res, body) =>
              @response = res
              @tool = JSON.parse res.body
              done()

          it 'creates a new tool', ->
            @response.should.have.status 201

          it 'records a "created" timestamp', ->
            should.exist @tool.created

          it 'records the owner', ->
            should.exist @tool.user

          it 'returns the newly created tool', ->
            should.exist @tool.name
            @tool.name.should.equal @toolName

          it 'is owned by me', ->
            @user.should.equal @tool.user

          it 'is private', ->
            @tool.public.should.be.false

          context 'when I update that tool', ->
            before (done) ->
              # short pause, to make sure the updated
              # timestamp is after the created one
              setTimeout done, 1

            before (done) ->
              request.post
                uri: "#{serverURL}/api/tools"
                form:
                  name: @toolName
                  type: 'view'
                  gitUrl: 'git://github.com/scraperwiki/spreadsheet-tool.git'
              , (err, res) =>
                @response = res
                @tool = JSON.parse res.body
                done()

            it 'updates the tool', ->
              @response.should.have.status 200

            it 'is still private', ->
              @tool.public.should.be.false

            it 'shows a recent "updated" timestamp', ->
              should.exist @tool.created
              should.exist @tool.updated
              @tool.updated.should.be.above @tool.created

            # We should check whether the manifest has been updated,
            # but it's hard.
            xit 'returns the updated tool', ->
              @tool.manifest.displayName.should.equal 'View Data 2'

        context 'When I create a private tool', ->
          before (done) ->
            request.post
              uri: "#{serverURL}/api/tools"
              form:
                name: "#{@toolName}-private"
                type: 'view'
                gitUrl: 'git://github.com/scraperwiki/test-app-tool.git'
                public: false
            , (err, res, body) =>
              @response = res
              @tool = JSON.parse res.body
              done()

          it 'creates a new tool', ->
            @response.should.have.status 201

          it 'is private', ->
            @tool.public.should.be.false

        context 'When I create a public tool', ->
          before (done) ->
            request.post
              uri: "#{serverURL}/api/tools"
              form:
                name: "#{@toolName}-public"
                type: 'view'
                gitUrl: 'git://github.com/scraperwiki/test-app-tool.git'
                public: true
            , (err, res, body) =>
              @response = res
              @tool = JSON.parse res.body
              done()

          it 'creates a new tool', ->
            @response.should.have.status 201

          it 'is public', ->
            @tool.public.should.be.true

      context 'GET /api/tools', ->
        before (done) ->
          request.get "#{serverURL}/api/tools", (err, res) =>
            @body = res.body
            @tools = JSON.parse @body
            done()

        it 'returns a list of tools', ->
          @tools.length.should.be.above 0

        it "includes my first tool", ->
          should.exist(_.find @tools, (x) => x.name == @toolName)

        it "includes my private tool", ->
          should.exist(_.find @tools, (x) => x.name == "#{@toolName}-private")

        it "includes my public tool", ->
          should.exist(_.find @tools, (x) => x.name == "#{@toolName}-public")

        it "includes public tools", ->
          should.exist(_.find @tools, (x) => x.name == "test-app")

        it 'returns the right fields', ->
          should.exist @tools[0].name
          should.exist @tools[0].gitUrl
          should.exist @tools[0].type

    describe 'Datasets', ->
      context 'when I create a dataset', ->

        createDatasets = (number, opts, callback) ->
          functionArr = []
          callback = opts unless arguments[2]?
          for i in [1..number]
            functionArr.push (cb) =>
              random = String(Math.random()*Math.pow(2,32))[0..4]
              request.post
                uri: "#{serverURL}/api/#{opts.user or 'ickletest'}/datasets"
                form:
                  displayName: opts.displayName or "Dataset #{random}"
                  tool: opts.tool or 'test-app'
              , cb

          async.series functionArr, (err, res) ->
            if res.length is 1
              callback err, res[0][0], res[0][1]
            else
              callback res

        before (done) ->
          createDatasets 1,
            displayName: 'Biscuit'
            tool: 'test-app'
            user: @user
          , (err, res, body) =>
            @response = res
            @dataset = JSON.parse res.body
            done()

        context 'POST /api/:user/datasets', ->
          it 'creates a new dataset', ->
            @response.should.have.status 200

          it 'returns the newly created dataset', ->
            should.exist @dataset.box
            @dataset.displayName.should.equal 'Biscuit'

          it 'has an associated boxServer...', ->
            should.exist @dataset.boxServer

        context 'GET /api/:user/datasets/:id', ->
          it 'returns a single dataset', (done)  ->
            request.get "#{serverURL}/api/#{@user}/datasets/#{@dataset.box}", (err, res) ->
              @dataset = JSON.parse res.body
              should.exist @dataset.box
              done()

          it "404 errors if the dataset doesn't exist", (done) ->
            request.get "#{serverURL}/api/#{@user}/datasets/NOTEXIST", (err, res) ->
              res.should.have.status 404
              done()

          it "403 errors if the user doesn't exist", (done) ->
            request.get "#{serverURL}/api/MRINVISIBLE/datasets/#{@dataset.box}", (err, res) ->
              res.should.have.status 403
              done()

          context 'I create some more', ->
            before (done) ->
              createDatasets 2, ->
                done()

            it "doesn't let me create the 4th one", (done) ->
              createDatasets 1, (err, res, body) ->
                res.should.have.status 402
                done()

        describe 'Views', ->
          context 'when I create a view on a dataset', ->
            before (done) ->
              request.post
                uri: "#{serverURL}/api/#{@user}/datasets/#{@dataset.box}/views"
                form:
                  name: 'carrottop'
                  displayName: 'Carrot Top'
                  tool: 'test-plugin'
              , (err, res, body) =>
                @response = res
                @view = JSON.parse res.body
                done()

            context 'POST /api/:user/datasets/<dataset>/views', ->
              it 'creates a new dataset', ->
                @response.should.have.status 200

              it 'returns the newly created view', ->
                should.exist @view.box
                @view.displayName.should.equal 'Carrot Top'

              it 'has an associated boxServer...', ->
                should.exist @view.boxServer


        context 'PUT /api/:user/datasets/:id', ->
          it 'changes the display name of a single dataset', (done) ->
            request.put
              uri: "#{serverURL}/api/#{@user}/datasets/#{@dataset.box}"
              form:
                displayName: 'Cheese'
            , (err, res) =>
              res.should.have.status 200
              request.get "#{serverURL}/api/#{@user}/datasets/#{@dataset.box}", (err, res) =>
                @dataset = JSON.parse res.body
                @dataset.displayName.should.equal 'Cheese'
                done(err)

          it 'changes the owner of a single dataset', (done) ->
            @newowner = 'ehg'
            request.put
              uri: "#{serverURL}/api/#{@user}/datasets/#{@dataset.box}"
              form:
                user: @newowner
            , (err, res) =>
              res.should.have.status 200
              done(err)

          it "that dataset doesn't appear in my list of datasets any more", (done) ->
            request.get "#{serverURL}/api/#{@user}/datasets", (err, res) =>
              res.body.should.not.include "#{@dataset.box}"
              done()

          it "404 errors if the dataset doesn't exist", (done) ->
            request.put "#{serverURL}/api/#{@user}/datasets/NOTEXIST", (err, res) ->
              res.should.have.status 404
              done()

      context 'GET: /api/:user/datasets', ->
        it 'returns a list of datasets', (done) ->
          request.get "#{serverURL}/api/#{@user}/datasets", (err, res) ->
            datasets = JSON.parse res.body
            datasets.length.should.be.above 0
            done err

      context 'POST: /api/:user/sshkeys', ->
        it 'returns ok', (done) ->
          request.post
            uri: "#{serverURL}/api/#{@user}/sshkeys"
            form:
              key: '  ssh-rsa AAAAB3NzaC1yc2EAAAAD...mRRu21YYMK7GSE7gZTtbI65WJfreqUY472s8HVIX foo@bar.local\n\n'
          , (err, res) ->
            res.body.should.include 'ok'
            done err

      context 'GET: /api/:user/sshkeys', ->
        it 'returns the key with whitespace trim', (done) ->
          request.get
            uri: "#{serverURL}/api/#{@user}/sshkeys"
          , (err, res) ->
            keys = JSON.parse res.body
            keys.should.include 'ssh-rsa AAAAB3NzaC1yc2EAAAAD...mRRu21YYMK7GSE7gZTtbI65WJfreqUY472s8HVIX foo@bar.local'
            done err

    describe 'Billing', ->
      context 'GET /api/:user/subscription/medium/sign', ->
        before (done) ->
          request.get
            uri: "#{serverURL}/api/#{@user}/subscription/medium/sign"
          , (err, res, body) =>
            @body = body
            done err

        it 'returns a signature', ->
          @body.should.match /\w+|.+/g

        it 'returns the unsigned contents', ->
          @body.should.include 'subscription[plan_code]=medium'

      context 'POST /api/:user/subscription/verify', ->
        before (done) ->
          request.post
            uri: "#{serverURL}/api/#{@user}/subscription/verify"
            form:
              recurly_token: '34324sdfsdf'
          , (err, res, body) =>
            @res = res
            done err

        it 'returns a 404 (the token is unknown)', ->
          @res.should.have.status 404

  describe 'Logging in as a different user', ->
    context "When I'm a staff member", ->
      before (done) ->
        # logout
        request.get "#{serverURL}/logout", done
      before (done) ->
        @loginURL = "#{serverURL}/login"
        @user = "teststaff"
        @password = process.env.CU_TEST_STAFF_PASSWORD
        request.get @loginURL, =>
          request.post
            uri: @loginURL
            form:
              username: @user
              password: @password
          , (err, res) =>
            @loginResponse = res
            done(err)

      before (done) ->
        request.get "#{serverURL}/api/tools", (err, res) =>
          @body = res.body
          @tools = JSON.parse @body
          done()

      it "does not see ickletest's first tool in tool list", ->
        should.not.exist(_.find @tools, (x) => x.name == @toolName)

      it "does not see ickletest's private tool in tool list", ->
        should.not.exist(_.find @tools, (x) => x.name == "#{@toolName}-private")

      it "does see ickletest's public tool in tool list", ->
        should.exist(_.find @tools, (x) => x.name == "#{@toolName}-public")

      it 'allows me to create a new profile', (done) ->
        @newUser = "new-#{String(Math.random()*Math.pow(2,32))[0..6]}"
        @newPassword = "newpass"
        request.post
          uri: "#{serverURL}/api/user"
          form:
            shortName: @newUser
            email: 'random@example.org'
            displayName: 'Ran Dom Test'
        , (err, resp, body) =>
          obj = JSON.parse body
          @token = obj.token
          resp.should.have.status 201
          done(err)
      it '... and I can set the password', (done) ->
        request.post
          uri: "#{serverURL}/api/token/#{@token}"
          form:
            password: @newPassword
        , (err, resp, body) ->
          resp.should.have.status 200
          done(err)
