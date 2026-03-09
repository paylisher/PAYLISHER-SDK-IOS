require 'xcodeproj'

project_path = 'Paylisher.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'PaylisherExample' }
if target.nil?
  puts "Target PaylisherExample not found"
  exit 1
end

group = project.main_group.find_subpath(File.join('PaylisherExample'), true)
group.set_source_tree('<group>')

# Files to add
files = ['FakeAuthManager.swift', 'LoginView.swift', 'ProfileView.swift']

files.each do |file_name|
    file_path = File.join('PaylisherExample', file_name)
    file_ref = group.find_file_by_path(file_name) || group.new_file(file_name)
    target.add_file_references([file_ref])
    puts "Added #{file_name} to target"
end

project.save
puts "Project saved"
