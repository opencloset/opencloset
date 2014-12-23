module.exports = function(grunt) {
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    coffee: {
      compileBare: {
        options: {
          bare: false,
          join: true
        },
        expand: true,
        cwd: 'coffee',
        src: ['*.coffee'],
        dest: 'coffee/js',
        ext: '.js'
      }
    },
    uglify: {
      options: {
        banner: '/*! <%= pkg.name %> - v<%= pkg.version %> - ' + 
          '<%= grunt.template.today("yyyy-mm-dd HH:MM:ss") %> */'
      },
      dist: {
        files: [{
          expand: true,
          cwd: 'coffee/js',
          src: '*.js',
          dest: 'public/js'
        }]
      }
    },
    watch: {
      js: {
        files: ['coffee/js/*.js'],
        tasks: 'uglify'
      },
      sass: {
        files: ['sass/*.scss'],
        tasks: 'compass'
      },
      coffee: {
        files: ['coffee/*.coffee'],
        tasks: 'coffee'
      }
    },
    compass: {
      dist: {
        options: {
          config: 'config.rb'
        }
      }
    }
  });
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-contrib-compass');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.registerTask('default', ['coffee', 'uglify', 'compass']);
};
