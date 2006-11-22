
require 'hashes2ostruct'
require 'erb'

def fix_dates(changelog)
  changelog.each do |release|
    if release.date.kind_of? String
      release.date = Time.parse(release.date)
    end
  end
end

def read_changelog(file)
  changelog_yaml = ERB.new(IO.read(file), nil, '0').result
  changelog = hashes2ostruct(YAML.load(changelog_yaml))
  fix_dates(changelog)
  return changelog
end