fs = require 'fs'
Registry = require 'npm-registry'
npm = require 'npm'
child_process = require 'child_process'
semver = require 'semver'
trampoline = require './trampoline'

module.exports = (grunt) ->

  npmreg = new Registry {}

  copy = (obj) ->
    cp = {}
    (cp[k] = obj[k]) for k of obj
    cp

  checkDependency = ({name, version}, pkg, callback) ->
    grunt.log.ok "Checking #{name}, currently at version #{version}"
    npmreg.packages.get name, (err, depPkg) ->
      if err? then return callback err
      latestVersion = depPkg[0].latest.version
      unless semver.gtr latestVersion, version then return callback null, pkg

      versions = releasesInRange (v for v of depPkg[0].releases), version, latestVersion

      grunt.log.ok "Found #{versions.length} more recent releases #{JSON.stringify versions}"

      findLatestWorkingVersion versions, name, (err, version) ->
        if err? then return callback err
        callback null, updateDependency(pkg, name, version)

  findLatestWorkingVersion = (versions, name, callback) ->
    checkRelease = (releases, workingVersion, callback) ->
      release = releases[0]
      grunt.log.ok "Checking version #{release}"
      install name, release, (err) ->
        if err? then return callback err
        build (err) ->
          callback null, releases[1..], unless err? then release

    trampoline
      args: [ versions, undefined ]
      fn: checkRelease
      done: (releases, version) -> version? or releases.length == 0
      ,
      (err, releases, version) ->
        if err? then callback err else callback null, version

  releasesInRange = (releases, versionA, versionB) ->
    releases.filter (r) -> semver.eq(r, versionB) or (semver.gtr(r, versionA) and semver.ltr(r, versionB))

  updateDependency = (pkg, name, version) ->
    updatedPkg = copy pkg
    updatedPkg.dependencies[name] = "=#{version}"
    updatedPkg

  install = (name, version, callback) ->
    npm.load {}, (err) ->
      if err? then return callback err
      npm.commands.install [ "#{name}@#{version}" ], (err) ->
        if err? then callback err else callback null
      npm.registry.log.on "log", (message) -> if ['warn', 'error'].indexOf(message.level) > -1 then grunt.log.warn "NPM INSTALL >> #{JSON.stringify message}"

  build = (callback) ->
    child_process.exec 'grunt test', (err, stdout, stderr) ->
      if err? then return callback err
      grunt.log.ok "Build successful..."
      callback null

  savePackageInfo = (pkg, callback) ->
    grunt.log.ok "Saving package info..."
    fs.writeFile 'package.json', JSON.stringify(pkg, null, 2), (err) ->
      if err? then callback err else callback null

  loadPackageInfo = (callback) ->
    grunt.log.ok "Loading package info..."
    fs.readFile 'package.json', 'utf8', (err, results) ->
      if err? then return callback err
      try
        callback null, JSON.parse results
      catch e
        callback e
        
  grunt.registerTask 'canary', 'Canary build support for grunt', ->
    done = this.async()
    loadPackageInfo (err, pkg) ->
      if err? then return done no
      dependencyList = ({ name: name, version: pkg.dependencies[name] } for name of pkg.dependencies)

      check = (deps, updatedPkg, callback) ->
        checkDependency deps[0], updatedPkg, (err, resultPkg) ->
          if err? then return callback err
          callback null, deps[1..], resultPkg

      trampoline
        args: [ dependencyList, pkg ]
        fn: check
        done: (deps) -> deps.length == 0
        ,
        (err, empty, results) ->
          if err? 
            grunt.log.warn "ERROR #{err}"
            done no
          else
            grunt.log.ok "Updated package info: #{JSON.stringify results, null, 2}"
            savePackageInfo results, (err) ->
              if err? 
                grunt.log.warn "FAILED TO SAVE PACKAGE INFO: #{JSON.stringify err}"
                done no
              else
                done yes