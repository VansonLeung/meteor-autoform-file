AutoForm.addInputType 'fileUpload',
  template: 'afFileUpload'
  valueOut: ->
    @val()

getCollection = (context) ->
  if typeof context.atts.collection == 'string'
    FS._collections[context.atts.collection] or window[context.atts.collection]

getDocument = (context) ->
  collection = getCollection context
  id = Template.instance()?.value?.get?()
  collection?.findOne(id)

getHidden = () ->
  t = Template.instance()
  t.hidden_dom
  
triggerHiddenChange = () ->
  setTimeout ( ->
    hidden_dom = getHidden()
    if hidden_dom
      hidden_dom.trigger('change')
  ), 100

Template.afFileUpload.onCreated ->
  self = @
  @value = new ReactiveVar @data.value

  @_stopInterceptValue = false
  @_interceptValue = (ctx) =>
    unless @_stopInterceptValue
      t = Template.instance()
      if t.value.get() isnt false and t.value.get() isnt ctx.value and ctx.value?.length > 0
        t.value.set ctx.value
        triggerHiddenChange()
        @_stopInterceptValue = true

  @_insert = (file) ->
    collection = getCollection self.data

    if Meteor.userId
      file.owner = Meteor.userId()

    if typeof self.data.atts?.onBeforeInsert is 'function'
      file = (self.data.atts.onBeforeInsert file) or file

    collection.insert file, (err, fileObj) ->
      if typeof self.data.atts?.onAfterInsert is 'function'
        self.data.atts.onAfterInsert err, fileObj

      fileObj.update $set: metadata: owner: Meteor.userId()

      if err then return console.log err
      self.value.set fileObj._id
      triggerHiddenChange()

  @autorun ->
    _id = self.value.get()
    _id and Meteor.subscribe 'autoformFileDoc', self.data.atts.collection, _id

Template.afFileUpload.onRendered ->
  self = @
  self.hidden_dom = $(self).find('input[type=hidden]')
  $(self.firstNode).closest('form').on 'reset', ->
    self.value.set false
    triggerHiddenChange()

Template.afFileUpload.helpers
  label: ->
    @atts.label or 'Choose file'
  removeLabel: ->
    @atts.removeLabel or 'Remove'
  value: ->
    doc = getDocument @
    doc?.isUploaded() and doc._id
  schemaKey: ->
    @atts['data-schema-key']
  previewTemplate: ->
    @atts?.previewTemplate or if getDocument(@)?.isImage() then 'afFileUploadThumbImg' else 'afFileUploadThumbIcon'
  previewTemplateData: ->
    file: getDocument @
    atts: @atts
  file: ->
    Template.instance()._interceptValue @
    getDocument @
  removeFileBtnTemplate: ->
    @atts?.removeFileBtnTemplate or 'afFileRemoveFileBtnTemplate'
  selectFileBtnTemplate: ->
    @atts?.selectFileBtnTemplate or 'afFileSelectFileBtnTemplate'
  selectFileBtnData: ->
    label: @atts.label or 'Choose file'
    accepts: @atts.accepts
  uploadProgressTemplate: ->
    @atts?.uploadProgressTemplate or 'afFileUploadProgress'

Template.afFileUpload.events
  "dragover .js-af-select-file": (e) ->
    e.stopPropagation()
    e.preventDefault()

  "dragenter .js-af-select-file": (e) ->
    e.stopPropagation()
    e.preventDefault()

  "drop .js-af-select-file": (e, t) ->
    e.stopPropagation()
    e.preventDefault()
    t._insert new FS.File e.originalEvent.dataTransfer.files[0]

  'click .js-af-remove-file': (e, t) ->
    e.preventDefault()
    t.value.set false
    triggerHiddenChange()

  'fileuploadchange .js-file': (e, t, data) ->
    t._insert new FS.File data.files[0]

Template.afFileUploadThumbImg.helpers
  url: ->
    @file.url store: @atts.store

Template.afFileUploadThumbIcon.helpers
  url: ->
    @file.url store: @atts.store
  icon: ->
    switch @file.extension()
      when 'pdf'
        'file-pdf-o'
      when 'doc', 'docx'
        'file-word-o'
      when 'ppt', 'avi', 'mov', 'mp4'
        'file-powerpoint-o'
      else
        'file-o'

Template.afFileSelectFileBtnTemplate.onRendered ->
  @$('.js-file').fileupload()
