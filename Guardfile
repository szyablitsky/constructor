extensions = %w(pages)

guard 'rspec', :spec_paths => extensions.map{|e| "#{e}/spec"}, :cli => (['~/.rspec', '.rspec'].map{|f| File.read(File.expand_path(f)).split("\n").join(' ') if File.exists?(File.expand_path(f))}.join(' ')) do
  extensions.each do |extension|
    watch(%r{^#{extension}/spec/.+_spec\.rb$})
    watch(%r{^#{extension}/app/(.+)\.rb$})                           { |m| "#{extension}/spec/#{m[1]}_spec.rb" }
    watch(%r{^#{extension}/lib/(.+)\.rb$})                           { |m| "#{extension}/spec/lib/#{m[1]}_spec.rb" }
    watch(%r{^#{extension}/app/controllers/(.+)_(controller)\.rb$})  { |m| ["#{extension}/spec/#{m[2]}s/#{m[1]}_#{m[2]}_spec.rb", "#{extension}/spec/features/#{m[1]}_spec.rb"] }
    watch(%r{^#{extension}/spec/support/(.+)\.rb$})                  { "#{extension}/spec" }
    watch("#{extension}/spec/spec_helper.rb")                        { "#{extension}/spec" }
    # Capybara request specs
    watch(%r{^#{extension}/app/views/(.+)/.*\.(erb|haml)$})          { |m| "#{extension}/spec/requests/#{m[1]}_spec.rb" }
  end
end

