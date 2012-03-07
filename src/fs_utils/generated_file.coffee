common = require './common'

# The definition would be added on top of every filewriter .js file.
requireDefinition = '''
(function(/*! Brunch !*/) {
  if (!this.require) {
    var modules = {}, cache = {}, require = function(name, root) {
      var module = cache[name], path = expand(root, name), fn;
      if (module) {
        return module;
      } else if (fn = modules[path] || modules[path = expand(path, './index')]) {
        module = {id: name, exports: {}};
        try {
          cache[name] = module.exports;
          fn(module.exports, function(name) {
            return require(name, dirname(path));
          }, module);
          return cache[name] = module.exports;
        } catch (err) {
          delete cache[name];
          throw err;
        }
      } else {
        throw 'module \\'' + name + '\\' not found';
      }
    }, expand = function(root, name) {
      var results = [], parts, part;
      if (/^\\.\\.?(\\/|$)/.test(name)) {
        parts = [root, name].join('/').split('/');
      } else {
        parts = name.split('/');
      }
      for (var i = 0, length = parts.length; i < length; i++) {
        part = parts[i];
        if (part == '..') {
          results.pop();
        } else if (part != '.' && part != '') {
          results.push(part);
        }
      }
      return results.join('/');
    }, dirname = function(path) {
      return path.split('/').slice(0, -1).join('/');
    };
    this.require = function(name) {
      return require(name, '');
    };
    this.require.brunch = true;
    this.require.define = function(bundle) {
      for (var key in bundle)
        modules[key] = bundle[key];
    };
  }
}).call(this);
'''

# Sorts by pattern.
# 
# Examples
#
#   sort ['b.coffee', 'c.coffee', 'a.coffee'],
#     before: ['a.coffee'], after: ['b.coffee']
#   # => ['a.coffee', 'c.coffee', 'b.coffee']
# 
sortByConfig = (files, config) ->
  return files if typeof config isnt 'object'
  config.before ?= []
  config.after ?= []
  # Clone data to a new array.
  [files...]
    .sort (a, b) ->
      # Try to find items in config.before.
      # Item that config.after contains would have bigger sorting index.
      indexOfA = config.before.indexOf a
      indexOfB = config.before.indexOf b
      [hasA, hasB] = [(indexOfA isnt -1), (indexOfB isnt -1)]
      if hasA and not hasB
        -1
      else if not hasA and hasB
        1
      else if hasA and hasB
        indexOfA - indexOfB
      else
        # Items wasn't found in config.before, try to find then in
        # config.after.
        # Item that config.after contains would have lower sorting index.
        indexOfA = config.after.indexOf a
        indexOfB = config.after.indexOf b
        [hasA, hasB] = [(indexOfA isnt -1), (indexOfB isnt -1)]
        if hasA and not hasB
          1
        else if not hasA and hasB
          -1
        else if hasA and hasB
          indexOfA - indexOfB
        else
          # If item path starts with 'vendor', it has bigger priority.
          aIsVendor = (a.indexOf 'vendor') is 0
          bIsVendor = (b.indexOf 'vendor') is 0
          if aIsVendor and not bIsVendor
            -1
          else if not aIsVendor and bIsVendor
            1
          else
            # All conditions were false, we don't care about order of
            # these two items.
            0

class exports.GeneratedFile
  constructor: (@path, @sourceFiles, @config) ->    
    @type = if (@sourceFiles.some (file) -> file.type is 'javascript')
      'javascript'
    else
      'stylesheet'

  _extractOrder: (files, config) ->
    types = files.map (file) -> common.pluralize file.type
    arrays = (value.order for own key, value of config.files when key in types)
    arrays.reduce (memo, array) ->
      array or= {}
      {
        before: memo.before.concat(array.before or []),
        after: memo.after.concat(array.after or [])
      }
    , {before: [], after: []}

  # Collects content from a list of files and wraps it with
  # require.js module definition if needed.
  joinSourceFiles: ->
    files = @sourceFiles
    pathes = files.map (file) -> file.path
    order = @_extractOrder files, @config
    sourceFiles = (sortByConfig pathes, order).map (file) ->
      files[pathes.indexOf file]
    data = ''
    data += requireDefinition if @type is 'javascript'
    data += sourceFiles.map((file) -> file.data).join ''
    data

  minify: (data, callback) ->
    if @minifier?.minify?
      @minifier.minify data, @path, callback
    else
      callback null, data

  write: (callback) ->
    files = (@sourceFiles.map (file) -> file.path).join(', ')
    logger.log 'debug', "Writing files '#{files}' to '#{@path}'"
    @minify @joinSourceFiles(), (error, data) =>
      common.writeFile @path, data, callback
