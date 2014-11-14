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
        cwd: 'public/js',
        src: ['*.coffee'],
        dest: 'public/js/',
        ext: '.js'
      }
    },
    uglify: {
      options: {
        banner: '/*! <%= pkg.name %> - v<%= pkg.version %> - ' + 
          '<%= grunt.template.today("yyyy-mm-dd") %> */'
      },
      dist: {
        files: [{
          expand: true,
          cwd: 'public/js',
          src: '**/*.js',
          dest: 'public/dist'
        }]
      }
    },
    watch: {
      js: {
        files: ['public/js/*.js'],
        tasks: 'uglify'
      },
      sass: {
        files: ['public/assets/sass/screen.scss'],
        tasks: 'compass'
      },
      coffee: {
        files: ['public/js/*.coffee'],
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
