namespace :i18n do
  desc 'find all translations in views, helpers and controllers'
  task :update => :environment do
    
    translations = {}
    raise "ERROR: APPLICATION_LANGUAGES = [['Deutsch', 'de'], ['English', 'en'], ...] is not defined - define it in your initializers" unless defined? APPLICATION_LANGUAGES
    raise "ERROR: DEFAULT_LANGUAGE = ['Deutsch', 'de'] e.g. is not defined - define it in your initializers" unless defined? DEFAULT_LANGUAGE
    
    # parse all view files for translations - removed ones get removed from
    # the i18n translation yml's automatically
    Dir.glob("**/*.{haml,erb}").each do |file|
      scan_for_translations(file, translations)
    end
    
    # also check helper files and controllers
    Dir.glob("**/*{_helper,_controller}.rb").each do |file|
      scan_for_translations(file, translations)
    end
    
    # rewrite default language file with updated translations
    puts "found #{translations.keys.size} unique translations"
    write_translation_file(DEFAULT_LANGUAGE[1], translations)
    
    # write a file for each foreign language
    (APPLICATION_LANGUAGES - [DEFAULT_LANGUAGE]).each do |language|
      # load foreign language file in temp hash
      if File.exists?("config/locales/application.#{language[1]}.yml")
        existing_translations = YAML.load_file("config/locales/application.#{language[1]}.yml")
        existing_translations = existing_translations[language[1]]
      else
        existing_translations = { language[1] => {} }
      end
      
      # delete removed translations from hash
      existing_translations.each_key do |key|
        existing_translations.delete(key) unless translations.has_key?(key)
      end
      
      # add new keys with empty translation to hash
      translations.each_key do |key|
        existing_translations[key] = "TRANSLATION_MISSING" unless existing_translations.has_key?(key)
      end
      write_translation_file(language[1], existing_translations)
    end
  end

  desc 'translate foreign language file line by line'
  task :translate => :environment do
    raise "ERROR: usage: TRANSLATE=de rake i18n:translate" unless ENV['TRANSLATE']
    language = ENV['TRANSLATE']
    if File.exists?("config/locales/application.#{language}.yml")
      existing_translations = YAML.load_file("config/locales/application.#{language}.yml")
      existing_translations = existing_translations[language]
      puts "Translating #{existing_translations.keys.size} entries to <#{language}> (enter :q to save and quit):"
      existing_translations.keys.sort.each do |key|
        if ["TRANSLATION_MISSING", ""].include?(existing_translations[key])
          puts "> #{key}"
          input = STDIN.gets.chomp
          if input == ":q"
            break
          else
            existing_translations[key] = input
          end
        end
      end
      
      puts "Schreiben der Datei config/locales/application.#{language}.yml"
      write_translation_file(language, existing_translations)
    else
      puts "ERROR: No translation file in config/locales/application.#{language}.yml"
      puts "Choosen language is invalid or you did not run rake i18n:update yet"
    end
  end
  
  def write_translation_file(language, translations)
    file = File.open("config/locales/application.#{language}.yml", "w")
    file.puts "# use rake task i18n:update to generate this file"
    file.puts
    file.puts "\"#{language}\":"
    translations.keys.sort do |a, b|
      a.downcase <=> b.downcase
    end.each do |key|
      file.puts "  \"#{key}\": \"#{translations[key]}\""
    end
    file.close
  end
  
  def scan_for_translations(file, translations)
    File.open(file) do |io|
      io.each do |line| 
        line.scan(/_\("([^"]+)"\)/) do |match|
          translations[match.first.gsub(/\./, '').strip] = match.first.strip
        end
        line.scan(/_\('([^']+)'\)/) do |match|
          translations[match.first.gsub(/\./, '').strip] = match.first.strip
        end
      end
    end
  end
end