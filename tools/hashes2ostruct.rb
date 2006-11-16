require 'ostruct'

def hashes2ostruct(object)
  object = object.dup
  return case object
  when Hash
    object.each do |key, value|
      object[key] = hashes2ostruct(value)
    end
    OpenStruct.new(object)
  when Array
    object.map! { |i| hashes2ostruct(i) }
  else
    object
  end
end
