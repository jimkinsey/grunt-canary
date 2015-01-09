module.exports = (grunt) ->
  grunt.initConfig
    coffee:
      compile:
        files: [
          expand: true,
          cwd: 'src',
          src: ['{,*/}*.coffee'],
          dest: 'tasks',
          ext: '.js'
        ]

    jasmine_node:
      options:
        forceExit: true
        match: '.'
        matchall: false
        specNameMatcher: 'spec'
        coffee: true
      all: ['test']

  grunt.loadTasks 'tasks'

  grunt.loadNpmTasks 'grunt-jasmine-node'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
      
  grunt.registerTask 'test', [ 'jasmine_node' ]
  grunt.registerTask 'default', [ 'test', 'coffee' ]
  grunt.registerTask 'build', [ 'test', 'coffee' ]
