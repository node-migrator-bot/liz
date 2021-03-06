
path = require 'path'
select = require('soupselect').select
u = require 'util'
fs = require 'fs'
sets = require 'simplesets'
htmlparser = require 'htmlparser'
hogan = require 'hogan.js'
_ = require 'underscore'

module.exports.extractTemplates = extractTemplates = (file) ->        
    templates = {}

    handler = new htmlparser.DefaultHandler (err, dom) ->
        if err then u.debug err
        loadTemplates = (template) -> templates[template.attribs.name] = template.children[0].raw.trim()
        select(dom, 'template').forEach loadTemplates
        select(dom, 'script').forEach loadTemplates
                
    parser = new htmlparser.Parser handler
    parser.parseComplete fs.readFileSync file, 'utf-8'
    templates

module.exports.createNamespaces = createNamespaces = (names) ->
    nameSet = new sets.Set names
    namespaces = new sets.Set []

    nameSet.each (name) ->        
        ns = []
        name.split('.').forEach (part) ->
            ns.push part            
            namespaces.add ns.join '.'

    namespaces.array().sort()

module.exports.buildFunctions = buildFunctions = (templates) ->
    _.keys(templates).reduce (container, key) ->         
        container[key] = hogan.compile templates[key], {asString: true}
        container
    , {}

module.exports.manage = manage = (files, outputFile) ->
    if path.existsSync outputFile then fs.unlinkSync outputFile    

    templateSets = files.map (file) -> buildFunctions extractTemplates file        
    templates = _.extend {}, templateSets...
    namespaces = createNamespaces _.keys templates

    output = []
    output.push "// AUTOGENERATED by liz.js on #{new Date()}. DO NOT EDIT."
    output.push "var hogan = require('hogan.js');"
    
    namespaces.forEach (ns) ->
        fn = if _.has(templates, ns) then "(function(){var _t=new hogan.Template(#{templates[ns]});return{_t:_t,render:function(){return _t.render.apply(_t,arguments)}};})()" else "{}"
        output.push "exports.#{ns} = #{fn};"
    output.push ''

    fs.writeFileSync outputFile, output.join('\n'), 'utf-8'
    console.log "Built #{_.keys(templates).length} templates into #{outputFile}"



    
    
