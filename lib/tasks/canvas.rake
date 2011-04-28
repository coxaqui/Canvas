def check_syntax(files)
  quick = ENV["quick"] && ENV["quick"] == "true" 

  files_not_to_lint = %w{
    public/javascripts/date.js
    public/javascripts/jquery-1.4.js
    public/javascripts/jquery.ba-hashchange.js
    public/javascripts/jquery-ui-1.8.js
    public/javascripts/jquery.ba-throttle-debounce.js
    public/javascripts/scribd.view.js
    public/javascripts/swfobject/swfobject.js
    public/javascripts/ui.selectmenu.js
    public/javascripts/raphael.js
    public/javascripts/g.raphael/g.raphael.js
    public/javascripts/g.raphael/g.pie.js
    public/javascripts/g.raphael/g.bar.js
    public/javascripts/g.raphael/g.dot.js
    public/javascripts/g.raphael/g.line.js
    public/javascripts/underscore.js
    public/flash/uploadify/jquery.uploadify.v2.1.0.js
    public/javascripts/json2.js
  }
  show_stoppers = []
  Array(files).each do |js_file|
    js_file.strip!
    if files_not_to_lint.include?(js_file) || !js_file.match('public/javascripts/')
      puts " --> \033[1;35m  skipping: #{js_file}\033[0m"
    else
      file_path = File.join(Rails.root, js_file)
      
      unless quick
        # to use this, you need to have jshint installed from npm 
        # (which means you need to have node.js installed)
        # on osx you can do:
        # brew install node
        # npm install jshint
        unless `which jshint`.empty?
          puts " --> \033[1;33m  Checking #{js_file} using JSHint: \033[0m"
          js_hint_errors = `jshint #{file_path} --config "#{File.join(Rails.root, '.jshintrc')}"`
          puts js_hint_errors
        end
        
        # Checks for coding style problems using google's js style guide.
        # Only works if you have gjslint installed.
        # Download from http://code.google.com/closure/utilities/
        unless `which gjslint`.empty?
          puts " --> \033[1;33m  Checking #{js_file} using gjslint.py: \033[0m"
          gjslint_errors = `gjslint --nojsdoc --strict #{js_file}`
          puts gjslint_errors = gjslint_errors.split("\n").reject{ |l| l.match("Line too long") }.join("\n")
        end
      end
      
      raise "jsl needs to be in your $PATH, download from: javascriptlint.com" if `which jsl`.empty?
      puts " --> \033[1;33m  Checking #{js_file} using jsl: \033[0m"
      jsl_output = `jsl -process "#{file_path}" -nologo -conf "#{File.join(Rails.root, 'config', 'jslint.conf')}"`
      exit_status = $?.exitstatus
      if exit_status != 0
        if exit_status >= 2
          show_stoppers << jsl_output 
          puts "\033[1;31m #{jsl_output} \033[0m"
        else
          puts jsl_output
        end
      end
    end
  end
  raise "\033[1;31m Fatal JavaScript errors found \033[0m" unless show_stoppers.empty?
end


namespace :canvas do
  desc "Compresses static assets"
  task :compress_assets do
    assets = FileList.new('public/**/*.js', 'public/**/*.css')
    before_bytes = 0
    after_bytes = 0
    processed = 0
    assets.each do |asset|
      asset_compressed = "#{asset}.gz"
      unless File.exists?(asset_compressed)
        `gzip --best --stdout "#{asset}" > "#{asset_compressed}"`
        before_bytes += File::Stat.new(asset).size
        after_bytes += File::Stat.new(asset_compressed).size
        processed += 1
      end
    end
    puts "Compressed #{processed} assets, #{before_bytes} -> #{after_bytes} bytes (#{"%.0f" % ((before_bytes.to_f - after_bytes.to_f) / before_bytes * 100)}% reduction)"
  end
  
  task :check_syntax  => "canvas:check_syntax:all"
  namespace :check_syntax do
    desc "Checks all js files that are staged for commiting to git for syntax errors. Make your .git/hooks/pre-commit look like: rake canvas:check_syntax:changed quick=true to not allow committing js with syntax errors"
    task :changed do
      files = `git diff-index --name-only --cached HEAD -- | grep '\.js$'`
      check_syntax(files)
    end
    
    desc "Checks all js files for sytax errors."
    task :all do
      bundles = YAML.load_file('config/assets.yml')['javascripts']
      bundles.each do |bundle_name, bundle_files|
        puts "------------------------------------------------------------"
        puts "checking bundle: " + bundle_name
        check_syntax(bundle_files)
      end
    end
  end
  
  desc "Compile javascript and css assets."
  task :compile_assets do
    puts "--> Compiling static assets [compass -s compressed --force]"
    output = `bundle exec compass -s compressed --force 2>&1`
    raise "Error running compass: \n#{output}\nABORTING" if $?.exitstatus != 0
    
    puts "--> Compiling static assets [jammit]"
    output = `bundle exec jammit 2>&1`
    raise "Error running jammit: \n#{output}\nABORTING" if $?.exitstatus != 0
  end
end

namespace :db do
  desc "Shows pending db migrations."
  task :pending_migrations => :environment do
    pending_migrations = ActiveRecord::Migrator.new(:up, 'db/migrate').pending_migrations
    pending_migrations.each do |pending_migration|
      puts '  %4d %s' % [pending_migration.version, pending_migration.name]
    end
  end

  namespace :test do
    unless Rake::Task.task_defined?('db:test:reset')
      task :reset => [:environment, :load_config] do
        raise "Run with RAILS_ENV=test" unless Rails.env.test?
        config = ActiveRecord::Base.configurations['test']
        queue = config['queue']
        drop_database(queue) if queue rescue nil
        drop_database(config) rescue nil
        create_database(queue) if queue
        create_database(config)
        Rake::Task['db:migrate'].invoke
      end
    end
  end
end
