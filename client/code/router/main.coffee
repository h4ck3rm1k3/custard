class Cu.Router.Main extends Backbone.Router
  tools: ->
    Cu.CollectionManager.get Cu.Collection.Tools

  datasets: ->
    Cu.CollectionManager.get Cu.Collection.Datasets

  initialize: ->
    @appView = new Cu.AppView '#content'
    @subnavView = new Cu.AppView '#subnav'
    @overlayView = new Cu.AppView '#overlay'
    @navView ?= new Cu.View.Nav()
    @errorView ?= new Cu.View.ErrorAlert el: '#error-alert'
    @on 'route', @errorView.hide
    @on 'route', @trackPageView
    @on 'route', @trackIntercom
    @on 'route', @trackOptimizely

    # TODO: this isn't a great place for this constant
    window.latestTerms = 1

    if window.user?.real
      if isNaN(window.user.real.acceptedTerms) or window.user.real.acceptedTerms < window.latestTerms
        @termsAlertView = new Cu.View.TermsAlert
        $("#header").after @termsAlertView.render().el

    # Backbone seems to reverse route order
    # TODO: revert to standard routes?
    @route RegExp('.*'), 'fourOhFour'
    @route RegExp('^/?$'), 'homeAnonymous'
    @route RegExp('^datasets?/?$'), 'homeLoggedIn'
    @route RegExp('^dashboard/?$'), 'dashboard'
    @route RegExp('(?:docs|help)/?'), 'help'
    @route RegExp('(?:docs|help)/([^/]+)/?'), 'help'
    @route RegExp('pricing/?'), 'pricing'
    @route RegExp('pricing/([^/]+)/?'), 'pricing'
    @route RegExp('chooser/?'), 'toolChooser'
    @route RegExp('tools/people-pack/?'), 'peoplePack'
    @route RegExp('dataset/([^/]+)/?'), 'dataset'
    @route RegExp('dataset/([^/]+)/settings/?'), 'datasetSettings'
    @route RegExp('dataset/([^/]+)/chooser/?'), 'datasetToolChooser'
    @route RegExp('dataset/([^/]+)/view/([^/]+)/?'), 'view'
    @route RegExp('create-profile/?'), 'createProfile'
    @route RegExp('set-password/?'), 'resetPassword'
    @route RegExp('set-password/([^/]+)/?'), 'setPassword'
    @route RegExp('signup/([^/]+)/?'), 'signUp'
    @route RegExp('subscribe/([^/]+)/?'), 'subscribe'
    @route RegExp('thankyou/?'), 'thankyou'
    @route RegExp('terms/?'), 'terms'
    @route RegExp('terms/enterprise-agreement/?'), 'termsEnterpriseAgreement'

  trackPageView: (e) ->
    path = Backbone.history.getFragment()
    _gaq.push ['_trackPageview', "/#{path}"]
    if 'real' of window.user
      _gaq.push ['_setCustomVar', 1, 'shortName', window.user.real.shortName, 1]

  trackOptimizely: (e) ->
    window.optimizely = window.optimizely or []
    # 'activate' seems to send the current URL to Optimizely
    # which is exactly what we want when pushState routing happens.
    window.optimizely.push ['activate']

  trackIntercom: ->
    if 'real' of window.user and window.intercomUserHash != ''
      @getIntercomSettings (intercomSettings) ->
        if window.intercomBooted?
          # tell Intercom we're still here
          window.Intercom 'update', intercomSettings
        else
          # start Intercom, and tell it we're here
          window.Intercom 'boot', intercomSettings
          window.intercomBooted = true
          # check for new Intercom messages/notifications every 30 seconds
          setInterval ->
            window.Intercom 'update'
          , 30000

  getIntercomSettings: (cb) ->
    real = window.user.real
    effective = window.user.effective

    app.tools().fetch
      success: =>
        app.datasets().fetch
          success: (model) =>
            datasets = model.toJSON()
            settings =
              app_id: window.intercomAppId
              user_hash: window.intercomUserHash
              widget:
                activator: "#intercomButton"
              user_id: real.shortName
              name: real.displayName
              email: real.email[0]
              created_at: moment(real.created, 'YYYY-MM-DD HH:mm:ssZ').unix()
              accountLevel: real.accountLevel
              datahub_id: effective.shortName
              datahub_name: effective.displayName
              datasets: datasets.length
              dataset_created_at: null
              tx_datasets: 0
              tx_downloads: 0
              tx_created_at: null
              ts_datasets: 0
              tf_datasets: 0
              cb_datasets: 0

            _.each datasets, (dataset) ->
              date = moment(dataset.createdDate, 'YYYY-MM-DD HH:mm:ssZ').unix()
              settings.dataset_created_at = Math.max date, settings.dataset_created_at
              if dataset.tool == 'table-xtract'
                settings.tx_created_at = Math.max date, settings.tx_created_at
                settings.tx_datasets += 1
                _.each dataset.views, (view) ->
                  if view.tool == 'spreadsheet-download'
                    settings.tx_downloads += 1
              else if dataset.tool == 'twitter-search'
                settings.ts_datasets += 1
              else if dataset.tool == 'twitter-follows'
                settings.tf_datasets += 1
              else if dataset.tool == 'code-scraper-in-browser'
                settings.cb_datasets += 1

            cb settings

  homeAnonymous: ->
    contentView = new Cu.View.Home
    @appView.showView contentView
    @subnavView.hideView()

  homeLoggedIn: ->
    $('#content').empty()
    app.tools().fetch().done =>
      contentView = new Cu.View.DatasetList
      subnavView = new Cu.View.DataHubNav
      @appView.showView contentView
      @subnavView.showView subnavView

  dashboard: ->
    contentView = new Cu.View.Dashboard
    window.document.title = 'Your dashboard | ScraperWiki'
    @appView.showView contentView
    @subnavView.hideView()

  pricing: (upgrade) ->
    subnavView = new Cu.View.Subnav PageTitles.pricing
    contentView = new Cu.View.Pricing upgrade: upgrade
    @appView.showView contentView
    @subnavView.showView subnavView

  signUp: (plan) ->
    contentView = new Cu.View.SignUp {plan: plan}
    subnavView = new Cu.View.SignUpNav {plan: plan}
    @appView.showView contentView
    @subnavView.showView subnavView

  thankyou: ->
    contentView = new Cu.View.Thankyou
    @appView.showView contentView
    @subnavView.hideView()

  toolChooser: ->
    chooserView = new Cu.View.ToolList {type: 'importers'}
    @overlayView.showView chooserView

  datasetToolChooser: (box) ->
    model = Cu.Model.Dataset.findOrCreate box: box
    model.fetch
      success: =>
        chooserView = new Cu.View.ToolList
          type: 'nonimporters'
          dataset: model
        @overlayView.showView chooserView

  subscribe: (truePlan) ->
    # TODO: make this a backbone model
    # TODO: handle unknown plan in sign api?
    shortName = window.user.effective.shortName
    humanPlan = window.app.humanPlan truePlan
    capitalisedPlan = humanPlan.toUpperCase()[0] + humanPlan.toLowerCase()[1..]
    $.ajax
      type: 'GET'
      url: "/api/#{shortName}/subscription/#{truePlan}/sign"
      success: (signature) =>
        contentView = new Cu.View.Subscribe {plan: truePlan, signature: signature}
        subnavView = new Cu.View.SignUpNav {plan: capitalisedPlan}
        @appView.showView contentView
        @subnavView.showView subnavView

  _ifDatasetIsNotDeleted: (model, callback) ->
    if model.get('state') == 'deleted'
      contentView = new Cu.View.DeletedDataset { model: model }
      @appView.showView contentView
      @subnavView.hideView()
    else
      callback()


  dataset: (box) ->
    model = Cu.Model.Dataset.findOrCreate box: box, merge: true
    toolsDone = app.tools().fetch()
    modelDone = model.fetch()

    modelDone.fail (jqXHR, textStatus, errorThrown) =>
      # 404? Reload the page directly from the server, so it can either render
      # a nice 404 page, or automatically switch the user into the right context.
      if jqXHR.status == 404
        window.aboutToClose = true
        window.location.reload()

    $.when.apply( null, [modelDone, toolsDone] ).done =>
      @_ifDatasetIsNotDeleted model, =>
        views = model.get 'views'
        unless @subnavView.currentView instanceof Cu.View.Toolbar
          subnavView = new Cu.View.Toolbar {model: model}
          @subnavView.showView subnavView
          window.selectedTool = model

        setTimeout =>
          views.findByToolName 'datatables-view-tool', (dataTablesView) =>
            if dataTablesView?
              window.selectedTool = dataTablesView
              subnavView = new Cu.View.Toolbar {model: model, view: dataTablesView}
              @subnavView.showView subnavView
              contentView = new Cu.View.PluginContent {model: dataTablesView}
              @appView.showView contentView
              contentView.showContent()
            else
              app.navigate "/dataset/#{model.id}/settings", trigger: true
        , 0

  datasetSettings: (box) ->
    mod = Cu.Model.Dataset.findOrCreate box: box
    mod.fetch
      success: (model) =>
        @_ifDatasetIsNotDeleted model, =>
          window.selectedTool = model
          unless @subnavView.currentView instanceof Cu.View.Toolbar
            subnavView = new Cu.View.Toolbar model: model
            @subnavView.showView subnavView
          contentView = new Cu.View.AppContent model: model
          @appView.showView contentView
          contentView.showContent()
      error: (_model, jqXHR) ->
        # 404? Reload the page directly from the server, so it can either render
        # a nice 404 page, or automatically switch the user into the right context.
        if jqXHR.status == 404
          window.aboutToClose = true
          window.location.reload()

  view: (datasetID, viewID) ->
    dataset = Cu.Model.Dataset.findOrCreate
      user: window.user.effective.shortName
      box: datasetID

    dataset.fetch
      success: (dataset, resp, options) =>
        @_ifDatasetIsNotDeleted dataset, =>
          v = dataset.get('views').findById(viewID)
          if not v?
            Backbone.trigger 'error', null, {responseText: "View not found"}
            return
          window.selectedTool = v
          contentView = new Cu.View.PluginContent model: v
          @appView.showView contentView
          contentView.showContent()
          unless @subnavView.currentView instanceof Cu.View.Toolbar
            subnavView = new Cu.View.Toolbar model: dataset, view: v
            @subnavView.showView subnavView
      error: (_model, jqXHR) ->
        # 404? Reload the page directly from the server, so it can either render
        # a nice 404 page, or automatically switch the user into the right context.
        if jqXHR.status == 404
          window.aboutToClose = true
          window.location.reload()

  peoplePack: ->
    subnavView = new Cu.View.ToolShopNav {name: 'People Pack', url: '/tools/people-pack'}
    contentView = new Cu.View.PeoplePack()
    @appView.showView contentView
    @subnavView.showView subnavView

  createProfile: ->
    if window.user.real.isStaff
      subnavView = new Cu.View.Subnav PageTitles['create-profile']
      contentView = new Cu.View.CreateProfile()
    else
      subnavView = new Cu.View.Subnav PageTitles['404']
      contentView = new Cu.View.FourOhFour()
    @appView.showView contentView
    @subnavView.showView subnavView

  resetPassword: ->
    subnavView = new Cu.View.Subnav PageTitles['reset-password']
    contentView = new Cu.View.ResetPassword()
    @appView.showView contentView
    @subnavView.showView subnavView

  setPassword: (token) ->
    $.ajax
      url: "/api/token/#{token}"
      dataType: 'json'
      success: (tokenInfo) =>
        if tokenInfo.shortName?
          @shortName = tokenInfo.shortName
        else
          Backbone.trigger 'error', null, {responseText: "no shortName!"}
      complete: =>
        subnavView = new Cu.View.Subnav PageTitles['set-password']
        contentView = new Cu.View.SetPassword {shortName: @shortName}
        @appView.showView contentView
        @subnavView.showView subnavView

  fourOhFour: ->
    subnavView = new Cu.View.Subnav PageTitles['404']
    contentView = new Cu.View.FourOhFour()
    @appView.showView contentView
    @subnavView.showView subnavView

  help: (section) ->
    section ?= 'home'
    subnavView = new Cu.View.HelpNav PageTitles["help-#{section}"]
    contentView = new Cu.View.Help {template: "help-#{section}"}
    @appView.showView contentView
    @subnavView.showView subnavView

  terms: ->
    subnavView = new Cu.View.Subnav PageTitles['terms']
    contentView = new Cu.View.Terms()
    @appView.showView contentView
    @subnavView.showView subnavView

  termsEnterpriseAgreement: ->
    subnavView = new Cu.View.Subnav PageTitles['terms-enterprise-agreement']
    contentView = new Cu.View.TermsEnterpriseAgreement()
    @appView.showView contentView
    @subnavView.showView subnavView

