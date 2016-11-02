module.exports = (grunt) ->
  'use strict'

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    # Task configuration
    clean:
      dist: ['coffee/js', 'public/js', 'public/css']

    coffee:
      dist:
        expand: true
        cwd: 'coffee'
        src: ['*.coffee']
        dest: 'coffee/js'
        ext: '.js'

    dump_dir:
      options:
        pre: 'window.pdfMake = window.pdfMake || {}; window.pdfMake.vfs = '
        rootPath: 'pdfmake/'
      dist:
        files:
          'public/components/pdfmake-dist/build/vfs_fonts_custom.js': [ 'pdfmake/*' ]

    uglify:
      options:
        mangle: true
        preserveComments: 'some'
      dist:
        expand: true
        cwd: 'coffee/js'
        src: ['**/*.js', '!**/*.min.js']
        dest: 'public/js'
        # ext: '.min.js'
      jst:
        expand: true
        cwd: 'public/js'
        src: ['templates.js']
        dest: 'public/js'

    csscomb:
      options:
        config: 'less/.csscomb.json'
      dist:
        expand: true
        cwd: 'public/css'
        src: ['*.css', '!*.min.css']
        dest: 'public/css'

    cssmin:
      options:
        compatibility: 'ie8'
        keepSpecialComments: '*'
        advanced: false
      dist:
        expand: true
        cwd: 'public/css'
        src: ['*.css', '!*.min.css']
        dest: 'public/css'
        ext: '.min.css'

    less:
      dist:
        options:
          strictMath: true
          sourceMap: true
          outputSourceFiles: true
        expand: true
        cwd: 'less'
        src: ['*.less']
        dest: 'public/css'
        ext: '.css'

    handlebars:
      options:
        namespace: 'JST'
        processName: (path) ->
          path.replace(/^public\/jst\//, '').replace(/\.hbs$/, '').replace(/\.html$/, '').replace(/\.jst$/, '')
      compile:
        files:
          'public/js/templates.js': ['public/jst/**/*.hbs', 'public/jst/**/*.html', 'public/jst/**/*.jst']

    watch:
      coffee:
        files: 'coffee/*.coffee'
        tasks: ['dist-js']
      less:
        files: 'less/*.less'
        tasks: ['dist-css']
      jst:
        files: ['public/jst/**/*.hbs', 'public/jst/**/*.html', 'public/jst/**/*.jst']
        tasks: ['dist-template']

  require('load-grunt-tasks')(grunt, { scope: 'devDependencies' })
  require('time-grunt')(grunt)

  grunt.registerTask('dist-js', ['coffee:dist', 'dump_dir:dist', 'uglify:dist'])
  grunt.registerTask('dist-css', ['less:dist', 'csscomb:dist', 'cssmin:dist'])
  grunt.registerTask('dist-template', ['handlebars:compile', 'uglify:jst'])
  grunt.registerTask('dist', ['clean', 'dist-template', 'dist-js', 'dist-css'])

  # Default task
  grunt.registerTask('default', ['dist'])
